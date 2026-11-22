# {__projectName__}

{__description__}

A full-stack project made with Mentenaz Forge: a React and TypeScript front end built with [Vite](https://vite.dev/), and a
Node and TypeScript API built with [Fastify](https://fastify.dev/), in one repository (npm workspaces).

## Scripts

Run these in this folder.

- `npm run dev` starts the API (port {__port__}) and the front end together. The front end forwards `/api` to the API, so it
  can call it without CORS.
- `npm run build` builds both. `npm test` runs the API's tests.

## Where things are

- `client/` is the Vite app. `client/src/App.tsx` calls the API and is the page you see first.
- `server/` is the API. `server/src/server.ts` holds the routes and `server/src/server.test.ts` shows how to test one.
- `client/vite.config.ts` sets the `/api` proxy. In production, serve the built client (`client/dist`) and the API behind
  one address that does the same.
