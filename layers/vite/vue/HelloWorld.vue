<script setup>
import { ref } from 'vue'
import heroImg from '../assets/hero.png'

const count = ref(0)
</script>

<template>
  <section id="center">
    <img :src="heroImg" width="170" height="179" alt="Mentenaz Forge" />
    <div>
      <h1>{__projectName__}</h1>
      <p>Made with Mentenaz Forge. Edit <code>src/App.vue</code> and save to see the page update.</p>
    </div>
    <button type="button" class="counter" @click="count++">
      Count is {{ count }}
    </button>
  </section>
</template>
