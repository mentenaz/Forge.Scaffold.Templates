  // allow browsers on other origins to call the API; narrow `origin` before you deploy
  await app.register(cors, { origin: true })

