# How to manage application state in large React projects, or format-agnostic data handling

At this article I'm going to explain the most efficient way to handle data at the application state that's coming from the server. This idea is library-agnistic and can be used with any library like Redux, MobX or [my own library](https://github.com/finom/use-change) (I recommend to check it out!). It's also going to probably useful with other rendering libraries such as Vue but I don't have enough experience with it to be sure.

The main concept of this idea is an **entity**. An entity is an object that comes from your database: a user, a company, a product, a something. Any entity can have dependencies in form of their properties. Let's use the following object as a reference to what I'm describibg here.

```ts
[{
  id: 'user_1',
  entityType: 'user',
  name: 'Bob Dowson',
  email: 'bob@example.com',
  company: {
    id: 'company_1',
    entityType: 'company',
    name: 'Project management Inc',
    products: [{
      id: 'product_1',
      entity_type: 'product',
      type: 'laptop',
      name: 'Macbook Air'
    }, {
      id: 'product_2',
      entity_type: 'product',
      type: 'smartphone',
      name: 'iPhone 16 Lame Edition'
    }]
  }
}]
```

(A user has an assigned company which in its turn has products that user can purchase. We need to render list of users with their products on a page)

I will explain `entityType` field below.

The object above is returned from some ORM call, let's imagine if we'd use Prisma.

```ts
const users = await prisma.user.fundMany({
  include: {
    company: {
      include: {
        products: true,
      }
    }
  }
});

return users;
```

How's that usually handled if you don't have a good strategy to do that?

```js
const resp = await (await (fetch('/users'))).json(); // WTF is in the resp?
```

You'd need to define a TypeScript interface (or utilise the type magic of Prisma) that describes what's needed to be returned. After that you're going to need to handle the response by using it directly at your component (if you make the fetch in `useEffect`) or in the application store.

If you work on a large app you should never fetch and handle API data manually at components because if your component is relatively big you're going to need to pass your reduced response to child components as props which decreased code quality and requires you to define child component props types. If you have many child components you're going to spend too much time on development. I strictly recommend to handle responses somewhere outside: if we talk about Redux that can be a middleware, a saga, an asynchronous action creator or something else.

Our goal is simplify API response as much as possible, to have as simple typings as possible, to make data handling as smooth as possible. That's the trick:

Your global application state (you can call it "store") is going to be split into multiple entities. For now we have user, company and product. Still, the idea is library-agnostic and I'm describibg only a shape of our store. What you're going to do and how it's going to be implemented is up to you.

The nested response from above needs to be parsed and **recursively flattened**.  We're going to replace nested entities with their ID. After the response is flattened we're going to get the following objects:

```
const users = [{
  id: 'user_1',
  entityType: 'user',
  name: 'Bob Dowson',
  email: 'bob@example.com',
  company: 'company_1', // replace the object by its ID
}];

const companies = [{
  id: 'company_1',
  entityType: 'company',
  name: 'Project management Inc',
  products: ['product_1', 'product_2']; // replace an array of objects by the array of its IDs
}];

// products are not modified since they have no nested entities
const products = [{
  id: 'product_1',
  entity_type: 'product',
  type: 'laptop',
  name: 'Macbook Air'
}, {
  id: 'product_2',
  entity_type: 'product',
  type: 'smartphone',
  name: 'iPhone 16 Lame Edition'
}]
```

Now let's build our store. The store is split by entities and every entity has `data` field. `data` is a key-value object where keys are entity IDs, and values are flattened entities themselves. To identify entity type and figure out where entities need to be stored we use `entityType` field that's a read-only DB field.

```ts
const rootStore = {
  someRootField: 1,
  users: {
    ids: ['user_1'], // I'll explain it below
    data: {
      user_1: {
        id: 'user_1',
        entityType: 'user',
        name: 'Bob Dowson',
        email: 'bob@example.com',
        company: 'company_1', // replace the object by its ID
      }
    }
  },
  companies: {
    data: {
      company_1: {
        id: 'company_1',
        entityType: 'company',
        name: 'Project management Inc',
        products: ['product_1', 'product_2']; // replace an array of objects by the array of its IDs
      }
    }
  },
  products: {
    data: {
      product_1: {
        id: 'product_1',
        entityType: 'product',
        type: 'laptop',
        name: 'Macbook Air'
      }, 
      product_2: {
        id: 'product_2',
        entityType: 'product',
        type: 'smartphone',
        name: 'iPhone 16 Lame Edition'
      }
    }
  }
}
```

Now you can have an ID or an array of IDs which allows you to easily get needed entities.

```ts
const company = rootStore.companies.data[user.company];
```

An obvious question: how can I get those IDs to map those users and render them on the page? I usually have a function that does all the flattening magic and **returns an ID or a list of IDs** instead of returning the entire response.

```js
const ids = await api('/users');
// rootStore.users.ids = ids <- you can store the IDs in your users part of store

const users = ids.map(id => rootStore.users.data[id]);
const companies = users.map(({ company }) => rootStore.companies.data[company]);
const products = companies.flatMap(({ products }) => products.map((productId) => rootStore.data.products[productId]));
```

I usually prefer to have a list of IDs in our store to make them available as part of React Context at every child component but that's not a requirement if your component is relatively simple and you don't need those IDs to be available globally.

Let's make a component that helps to summarise everything what's said above.

```ts
const Users = () => {
  const [ids, setIds] = useState([]);
  const { data } = rootStore.users;
  
  // we don't really need useMemo here, but that's just for simplicity
  const users = useMemo(() => ids.map((id) => data[id]), [ids]);
  
  const loadUsers = useCallback(async () => {
     const userIds = await api('/users');
     setIds(userIds);
  }, [])
  
  useEffect(() => {
    void loadUsers();
  }, [loadUsers]);
  
  return (
    <div>{users.map(/*...*/)}</div>
  )
}
```

From now if you want to create a child component that needs access to a specified entity, you should pass its id instead of passing the entire entity object. Then the child component is going to "decide" what other data it needs. Parent component doesn't need to "worry" about what format of data should be passed into the child component.

```jsx
<UserInfo id={userId} />
```

```jsx
interface Props {
  id: string;
}

/*
VS:

interface Props {
  user: User & { company: Company & { products: Product[]; } };
}
*/

const UserInfo = ({ id }: Props) => {
  const user = useGetUserFromStoreSomehow(id);
}
```

That's it. If you have any question or an idea please open an issue or send me a DM.

## What we've achieved?

- We don't need to handle nested data anymore.
- We don't care what response format we expect from the server, the only thing we need is an ID or a list of IDs.
- We've simplified typing.
- We've built the store the way when it's going to be always extensible, even if you have a lot of entity types (tens or even hundreds?), a lot of features and pages.
- We've decreased probability of bugs.
- The app state structure is clear and understabdable to new team members.
- We write less code thanks to the automatic response handling.
- We've got all those antities available everywhere within the app, not depending on what is going to use them and how they're going to be used, thanks to the simple key-value storage for entities.
- We don't need to worry about what server-side function is going to return, that's what I call **format-agnostic**.
- Cheaper development!
