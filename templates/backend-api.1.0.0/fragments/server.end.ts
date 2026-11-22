  app.get('/health', async () => ({ status: 'ok' }))

  return app
}
