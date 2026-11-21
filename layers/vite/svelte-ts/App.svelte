<script lang="ts">
  import heroImg from './assets/hero.png'
  import Counter from './lib/Counter.svelte'
</script>

<section id="center">
  <img src={heroImg} width="170" height="179" alt="Mentenaz Forge" />
  <div>
    <h1>{__projectName__}</h1>
    <p>Made with Mentenaz Forge. Edit <code>src/App.svelte</code> and save to see the page update.</p>
  </div>
  <Counter />
</section>
