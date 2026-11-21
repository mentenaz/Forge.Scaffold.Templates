import { component$, useSignal } from '@builder.io/qwik'

import heroImg from './assets/hero.png'
import './app.css'

export const App = component$(() => {
  const count = useSignal(0)

  return (
    <section id="center">
      <img src={heroImg} width="170" height="179" alt="Mentenaz Forge" />
      <div>
        <h1>{__projectName__}</h1>
        <p>
          Made with Mentenaz Forge. Edit <code>src/app.jsx</code> and save to see the page update.
        </p>
      </div>
      <button type="button" class="counter" onClick$={() => count.value++}>
        Count is {count.value}
      </button>
    </section>
  )
})
