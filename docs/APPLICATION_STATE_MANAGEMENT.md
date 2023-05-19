# How to manage application state in large React projects, or format-agnostic data handling

At this article I'm going to explain the most efficient way to handle data at the application state that's coming from the server. This idea is library-agnistic and can be used with any library like Redux or MobX. It's also going to probably useful with other rendering libraries such as Vue but I don't have enough experience with it to be sure.

The main concept of this idea is an **entity**. An entity is an object that comes from your database: a user, a company, a product, a something. Any entity can have dependencies in form of their properties. Let's use the following object as a reference to what I'm describibg here.

```ts
[{
  id: '...',
  entityType: 'user',
  name: 'Bob Dowson',
  email: 'bob@example.com',
  company: {
    id: '...',
    entityType: 'company',
    name: 'Project management Inc',
    products: [{
      id: '...',
      entity_type: 'product',
      type: 'laptop',
      name: 'Macbook Air'
    }, {
      id: '...',
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
const user = await prisma.user.fundMany({
  include: {
    company: {
      include: {
        products: true,
      }
    }
  }
});

return user;
```

How's that usually handled if you don't have a good strategy to do that?

```js
const resp = await (await (fetch('...'))).json(); // WTF is in the resp?
```

You'd need to define a TypeScript type (or utilise the type magic of Prisma) that describes what's needed to be returned. After that you're going to need to handle the response by using it directly at your component (if you make the fetch in `useEffect`) or in the application store.

If you work on a large app you should never fetch and handle API data at components because if your component is relatively big you're going to need to pass your reduced response to child components as props which decreased code quality and requires you to define child component props. If you have many child components you're going to spend too much time on development. I strictly recommend to handle responses   
