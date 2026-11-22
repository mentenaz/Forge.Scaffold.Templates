import { test } from 'node:test'
import assert from 'node:assert/strict'
import { buildServer } from './server.js'

test('GET /api/health says the server is ok', async () => {
  const app = await buildServer()
  const res = await app.inject({ method: 'GET', url: '/api/health' })
  assert.equal(res.statusCode, 200)
  assert.deepEqual(res.json(), { status: 'ok' })
  await app.close()
})
