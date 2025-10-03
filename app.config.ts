// app.config.ts
import { defineAppConfig } from 'nuxt/app'

export default defineAppConfig({
  ui: {
    primary: 'brand',
    gray: 'neutral',
    button: {
      default: {
        color: 'primary',
        variant: 'solid',
        size: 'lg'
      }
    }
  }
})

