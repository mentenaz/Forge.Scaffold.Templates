import { useEffect, useState } from 'react'
import './App.css'

type Health = { status: string }

function App() {
  const [health, setHealth] = useState<Health | null>(null)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    fetch('/api/health')
      .then((res) => res.json() as Promise<Health>)
      .then(setHealth)
      .catch((err: unknown) => setError(String(err)))
  }, [])

  return (
    <main>
      <h1>{__projectName__}</h1>
      <p>
        Made with Mentenaz Forge. Edit <code>client/src/App.tsx</code> and save to see the page update.
      </p>
      <p>
        API: {error ? `not reachable (${error})` : health ? health.status : 'checking...'}
      </p>
    </main>
  )
}

export default App
