import Fastify from 'fastify'

export async function buildServer() {
  const app = Fastify({ logger: process.env.NODE_ENV !== 'test' })

  app.get('/api/health', async () => ({ status: 'ok' }))

  return app
}
