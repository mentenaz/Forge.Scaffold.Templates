import { createSignal } from 'solid-js'
import heroImg from './assets/hero.png'
import './App.css'

function App() {
  const [count, setCount] = createSignal(0)

  return (
    <section id="center">
      <img src={heroImg} width="170" height="179" alt="Mentenaz Forge" />
      <div>
        <h1>{__projectName__}</h1>
        <p>
          Made with Mentenaz Forge. Edit <code>src/App.tsx</code> and save to see the page update.
        </p>
      </div>
      <button type="button" class="counter" onClick={() => setCount((count) => count + 1)}>
        Count is {count()}
      </button>
    </section>
  )
}

export default App
