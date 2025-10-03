import type { Config } from 'tailwindcss'

export default <Partial<Config>>{
  content: [
    './app/**/*.{vue,js,ts}',
    './components/**/*.{vue,js,ts}'
  ],
  theme: {
    extend: {
      colors: {
        brand: '#00DC82'
      }
    }
  }
}
