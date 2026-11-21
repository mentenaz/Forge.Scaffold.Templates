import './style.css'
import heroImg from './assets/hero.png'
import { setupCounter } from './counter.js'

document.querySelector('#app').innerHTML = `
<section id="center">
  <img src="${heroImg}" width="170" height="179" alt="Mentenaz Forge">
  <div>
    <h1>{__projectName__}</h1>
    <p>Made with Mentenaz Forge. Edit <code>src/main.js</code> and save to see the page update.</p>
  </div>
  <button id="counter" type="button" class="counter"></button>
</section>
`

setupCounter(document.querySelector('#counter'))
