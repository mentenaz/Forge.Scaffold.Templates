import { useState } from 'react'
import heroImg from './assets/hero.png'
import './App.css'

function App() {
  const [count, setCount] = useState(0)

  return (
    <section id="welcome">
      <img src={heroImg} width="170" height="179" alt="Mentenaz Forge" />
      <h1>{__projectName__}</h1>
      <p>
        Made with Mentenaz Forge. Edit <code>src/App.tsx</code> and save to see the page update.
      </p>
      <button
        type="button"
        className="counter"
        onClick={() => setCount((count) => count + 1)}
      >
        Count is {count}
      </button>
    </section>
  )
}

export default App
