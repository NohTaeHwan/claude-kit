# [프로젝트명] — Claude 개발 컨텍스트

## 프로젝트
[프로젝트 한 줄 설명]
- Vue 3 + Vite
- TypeScript
- 상태관리: Pinia
- 라우터: Vue Router 4
- [UI 라이브러리: 예) Vuetify / Element Plus / shadcn-vue / 없음]
- [API 통신: axios]
- src 루트: `src/`

---

## 개발 유의사항 (항상 준수)

1. **작업 시작 전 참고 문서 이정표 확인** — 사용자 요청을 받으면 아래 "참고 문서 이정표"를 확인하여 연관된 문서가 있으면 작업 전에 반드시 읽고 시작
2. **`<script setup lang="ts">` 필수** — Options API 사용 금지. 모든 SFC는 Composition API + `<script setup>` 방식으로 작성
3. **SFC 블록 순서 고정** — `<script setup>` → `<template>` → `<style scoped>` 순서 준수
4. **컴포넌트 이름 규칙** — PascalCase 다중 단어 사용 필수, 단일 단어 이름 금지 (예: `UserCard.vue` ✅ / `User.vue` ❌)
5. **Props / Emits 타입 선언 필수** — `defineProps<{ ... }>()` · `defineEmits<{ ... }>()` TypeScript 제네릭 방식 사용. Props를 컴포넌트 내부에서 직접 변이하지 않는다
6. **재사용 로직은 Composable로 분리** — `src/composables/use[Name].ts` 패턴 사용. 컴포넌트 내 비템플릿 로직이 10줄 이상이면 Composable 분리를 검토
7. **API 호출 레이어 분리** — 컴포넌트·composable에서 직접 axios 호출 금지. `src/services/[domain]Service.ts`에 캡슐화 후 composable을 통해 호출
8. **Pinia store 규칙** — 컴포넌트 간 공유 상태는 Pinia store 사용. store에서 반환한 ref를 구조분해할 때 반드시 `storeToRefs()` 사용 (반응성 손실 방지). 비동기 로직은 action에 집중
9. **비동기 처리 시 로딩·에러 상태 필수** — API 호출 composable에 `isLoading ref<boolean>`, `error ref<string | null>` 항상 포함
10. **`v-for` `:key` 규칙** — `:key`는 배열 index가 아닌 고유 식별자 사용 (예: `:key="item.id"`)
11. **`v-if` + `v-for` 동시 사용 금지** — 같은 요소에 두 디렉티브를 함께 사용 금지. `<template v-for>` + 내부 `v-if` 구조로 분리
12. **`<style scoped>` 기본 사용** — 전역 스타일은 `src/assets/styles/`에만 작성. 컴포넌트 스타일은 반드시 `scoped` 적용
13. **import 절대경로 사용** — `../../components/...` 대신 `@/components/...` 형식 사용
14. **컴포넌트·기능 작업 완료 후 아래 항목을 반드시 순서대로 처리하고 마무리**
    - [ ] 컴포넌트·composable 단위 테스트 작성 및 통과 확인 (Vitest + @vue/test-utils)
    - [ ] TypeScript 타입 오류 없음 확인 (`vue-tsc --noEmit`)
    - [ ] ESLint 경고 없음 확인
    - [ ] `docs/dev_context.md` 업데이트 (신규 컴포넌트·composable·store·라우트 추가 시)
    - [ ] README.md 업데이트 (화면 또는 주요 기능 추가·변경 시)
15. **CLAUDE.md 및 `docs/dev_context.md` 항상 최신화** — 신규 컴포넌트·composable·store·라우트 추가 시 즉시 업데이트

---

## 코드 구조 규칙

### 디렉토리 구조

```
src/
├── assets/
│   └── styles/           ← 전역 스타일 (variables, reset 등)
├── components/
│   ├── common/           ← 프로젝트 전반 재사용 컴포넌트 (BaseButton, BaseModal 등)
│   └── [domain]/         ← 도메인별 컴포넌트
├── composables/          ← useXxx.ts 패턴 (비즈니스 로직 + 상태)
├── router/               ← index.ts + 도메인별 라우트 모듈
├── services/             ← [domain]Service.ts (axios 호출만 담당)
├── stores/               ← [domain]Store.ts (Pinia, 컴포넌트 간 공유 상태)
├── types/                ← 공통 TypeScript interface / type / enum
├── utils/                ← 순수 헬퍼 함수 (날짜 포맷, 유효성 검사 등)
└── views/                ← 라우트 단위 페이지 컴포넌트 (composable 조합만)
```

### Composable 작성 패턴

```ts
// src/composables/useUser.ts
export function useUser() {
  const isLoading = ref(false)
  const error = ref<string | null>(null)

  async function fetchUser(id: number): Promise<User | undefined> {
    isLoading.value = true
    error.value = null
    try {
      return await userService.getById(id)
    } catch {
      error.value = '사용자 조회에 실패했습니다.'
    } finally {
      isLoading.value = false
    }
  }

  return { isLoading, error, fetchUser }
}
```

### Pinia Store 패턴

```ts
// src/stores/userStore.ts
export const useUserStore = defineStore('user', () => {
  const list = ref<User[]>([])

  async function fetchList() {
    list.value = await userService.getList()
  }

  return { list, fetchList }
})

// 컴포넌트에서 사용 시
const store = useUserStore()
const { list } = storeToRefs(store)  // storeToRefs 필수 — 직접 구조분해 금지
```

### Props / Emits 선언 패턴

```ts
// Props
const props = defineProps<{
  userId: number
  label?: string       // ?는 optional
}>()

// Emits
const emit = defineEmits<{
  confirm: [id: number]
  cancel: []
}>()
```

### 비동기 컴포넌트 (코드 스플리팅)

라우트 단위 컴포넌트는 `defineAsyncComponent` 또는 라우터의 동적 import로 분리:

```ts
// router/index.ts
{ path: '/users', component: () => import('@/views/UserView.vue') }
```

---

## 테스트 작성 규칙

- **단위 테스트**: Vitest 사용 (`describe`, `it`, `expect`)
- **컴포넌트 테스트**: `@vue/test-utils`의 `mount` / `shallowMount` 사용
- **composable 테스트**: composable을 직접 호출하고 반환값 검증 (컴포넌트 없이 테스트 가능)
- **store mock**: `createTestingPinia()` 사용 (`@pinia/testing` 패키지)
- **service mock**: `vi.mock('@/services/userService')` 방식으로 axios 레이어만 모킹

---

## 프로젝트 커스텀 규칙 (아래에 추가)

> 이 섹션에 프로젝트 고유 규칙을 추가한다.
> 예시: UI 라이브러리 컴포넌트 네이밍, 폼 유효성 검사 방식 (VeeValidate / zod 등), 인증 방식, 도메인별 특이사항 등

---

## 참고 문서 이정표

> 아래 표를 프로젝트 문서 구조에 맞게 채운다.

| 상황 | 읽을 파일 |
|---|---|
| 컴포넌트·화면 개발·수정 시 | `docs/dev_context.md` |
| API 엔드포인트 확인 시 | `docs/api_specification.md` |
| 라우트 구조 확인 시 | `docs/route_map.md` |
| 배포·운영 작업 시 | `docs/deploy_guide.md` |
| Git push·PR 시 | remote: `[SSH 원격 주소]` |
