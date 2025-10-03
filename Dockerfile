# ---------- Base versions ----------
# เลือก LTS จะปลอดภัยกับ Nuxt 4
ARG NODE_VERSION=20-alpine

# ---------- Development ----------
FROM node:${NODE_VERSION} AS dev
WORKDIR /app

# ติดตั้ง dependencies ตาม lockfile (รองรับทั้ง npm / pnpm / yarn)
COPY package*.json ./
RUN npm ci

# คัดลอกซอร์ส
COPY . .

# ให้ Nuxt bind 0.0.0.0 เพื่อเข้าจากข้างนอก container
ENV HOST=0.0.0.0
EXPOSE 3000

# ใช้ "-- -o" เพื่อไม่เปิดเบราว์เซอร์ในคอนเทนเนอร์
CMD ["npm", "run", "dev", "--", "-o"]

# ---------- Build (Production) ----------
FROM node:${NODE_VERSION} AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
# สร้างไฟล์ .output (Nitro)
RUN npm run build

# ---------- Runner (Production) ----------
FROM node:${NODE_VERSION} AS runner
WORKDIR /app

ENV NODE_ENV=production
ENV NITRO_HOST=0.0.0.0
ENV NITRO_PORT=3000
EXPOSE 3000

# คัดลอกเฉพาะผลลัพธ์ที่จำเป็นสำหรับรันจริง
COPY --from=build /app/.output ./.output

# รันเซิร์ฟเวอร์ Nitro ของ Nuxt
CMD ["node", ".output/server/index.mjs"]
