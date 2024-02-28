# Recommended technological stack for a full-stack application

(Thie article doesn't make sense today, I need to review and rewrite it)

The goal:
- Make development be faster and efficient (cheaper).
- Make developer's communication within the team as shorter as possible (we don't block each other).
- Cover 100% needs of a monolithic application and make development performance independent from number of features.


## Common

### General tools

- TypeScript
- ESLint
- npm-check-updates to keep our dependencies up to date
- Storybook (if needed)
- Testsing framework is a large topic and it needs to be solved individually

### Authentication and authorisation

The easiest and the cheapest way to implement authentication and authorisation is to use a third-party service such as [Auth0](https://auth0.com/). Both processes are quite simple, front-end requires a hook to be used, and back-end neess to authorise requests incoming from front-end. There is an example of such authorisation function below.

## Back-end

### ORM

[Prisma](https://www.prisma.io/) as the most effecient ORM for common databases (Mongo, Postgres etc). 

#### Why?
- It allows to define DB shema in one file with nice and friendly syntax.
- It generates TypeScript definitions with a simple command `npx prisma generate`.
- Nice and smooth DB migrations via `npx prisma migrate dev`.

```prisma
model User {
  id               String @id @default(uuid())
  createdAt        DateTime @default(now())
  updatedAt        DateTime @updatedAt
  email            String @unique
}
```


```ts
prisma.user.findMany(/* ... */); // TypeScript autonatically knows that prisma has "user" instance
```

### Framework

[NestJS](https://nestjs.com/) as the nicest way to define API endpoints. Please never use Express.js as it is! NestJS gives a stricture to our code and allows to define some extra features such as list of permissions or AuthGuard.

```ts
@Controller('/users')
export class UserController {
  constructor(private readonly usersService: UserService) {}
  @Permissions(['ADMIN'])
  @UseGuards(AuthGuard)
  @Post('/')
  createUser(
    @Body() body: Partial<User>
  ) {
    return this.usersService.createUser(body);
  }
}
```

At example above all the requests to the given endpoint are run thru AuthGuard, which in its turn checks JWT token for validity, extracts user ID, checks for user permission etc. An example of AuthGuard that handles Auth0 authorisation:


```ts
@Injectable()
export class AuthGuard implements CanActivate {
  constructor(private userService: UserService, private reflector: Reflector) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    
    const requirePermissions = this.reflector.getAllAndOverride<Permission[]>('permissions', [
      context.getHandler(),
      context.getClass(),
    ]);

    const req: GuardRequest = context.getArgByIndex(0);
    const res: Response = context.getArgByIndex(1);

    const checkJwt = jwt({
      secret: expressJwtSecret({
        cache: true,
        rateLimit: true,
        jwksRequestsPerMinute: 5,
        jwksUri: `${process.env.AUTH0_ISSUER_URL}.well-known/jwks.json`,
      }),
      audience: process.env.AUTH0_AUDIENCE,
      issuer: process.env.AUTH0_ISSUER_URL,
      algorithms: ['RS256'],
    });

    if (!req.headers.authorization) {
      throw new UnauthorizedException();
    }

    const token = req.headers.authorization.split(' ')[1];

    try {
      await checkJwt(req, res, () => {});
    } catch (e) {
      console.error(e);
      throw new UnauthorizedException();
    }

    const decodedToken = jwtDecode(token) as JWTDecoded;

    const { sub, permissions, email } = decodedToken;

    req.token = token;
    req.decodedToken = decodedToken;

    return true; // false if user has no access
  }
}
```

## Ftont-end

### Framework 

[NextJS](https://nextjs.org/)

#### Why?

This is the best React framework so far. I don't need to set up Babel, Webpack, Babel plugins, Webpack loaders, React Hot Loader etc which sometimes take multiple days because of various reasons (bad docs, doesn't work in our particular case, isn't compatible with other libraries). With NextJS I can set up the entire framework with TypeScript, Tailwind, nice file structure with one simple command.

Why we don't use /api folder to create APIs? Because NextJS isn't as good as NestJS even after they introduced the /app folder.


### CSS tool

[Tailwind](https://tailwindcss.com/) for fast and effecient styling. 

#### Why?

There is nothing as efficient as Tailwind: neither of BEM, CSS modules, and even styled components. Critics of this tool usually say that your classNames aren't modular and cannot be re-used somewhere else. That's true but only for pure HTML where you need to repeat same code with small modifications multiple times. But in React that's not really correct because your modularity comes from component architecture. 

```tsx
<Button>Click me</Button>
```

And you shouldn't care if your Button internally looks not that nice:

```tsx
<a class="inline-block px-4 py-3
    text-sm font-semibold text-center
    text-white uppercase transition
    duration-200 ease-in-out bg-indigo-600 
    rounded-md cursor-pointer
    hover:bg-indigo-700">{children}</a>
```

...because, thanks to modules we don't need to care about how a particular component were implemented.



 
