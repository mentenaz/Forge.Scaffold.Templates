
export async function buildServer() {
  const app = Fastify({ logger: process.env.NODE_ENV !== 'test' })

