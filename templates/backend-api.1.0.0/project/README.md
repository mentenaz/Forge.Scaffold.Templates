# {__projectName__}

{__description__}

A Node and TypeScript API made with Mentenaz Forge. It uses [Fastify](https://fastify.dev/).

## Scripts

- `npm run dev` starts the server and restarts it when you save a file.
- `npm run build` compiles to `dist/`, and `npm start` runs the build.
- `npm test` runs the tests (Node's built-in test runner).

The server listens on port {__port__} (set `PORT` to change it). Try `curl http://localhost:{__port__}/health`.

## Where things are

- `src/server.ts` builds the server and holds the routes, so a test can create one without listening on a port.
- `src/index.ts` starts it.
- `src/server.test.ts` shows how to test a route without a network.
