# [프로젝트명] — Claude 개발 컨텍스트

## 프로젝트
[프로젝트 한 줄 설명]
- [Java 버전], [Spring Boot 버전]
- [ORM 선택: JPA / MyBatis 등]
- [DB 선택: MySQL / PostgreSQL 등]
- 패키지 루트: `[com.example.프로젝트]`

> 위 placeholder를 프로젝트의 실제 값으로 채운다. API 작업 전 `pom.xml`, `build.gradle(.kts)`, Java toolchain 등 프로젝트 설정에서 실제 Java·Spring Boot 버전을 확인한다.
> JPA/MyBatis 적용 방식은 의존성만으로 정하지 않고 변경 대상 도메인의 기존 구조를 우선한다.
> 프로젝트에서 OpenAPI 또는 Swagger를 사용 중일 때만 기존 명세 방식을 따른다. 사용하지 않는 프로젝트에 관련 의존성·annotation·파일을 추가하지 않는다.

---

## 개발 유의사항 (항상 준수)

1. **작업 시작 전 참고 문서 이정표 확인** — 사용자 요청을 받으면 아래 "참고 문서 이정표"를 확인하여 연관된 문서가 있으면 작업 전에 반드시 읽고 시작
2. **API 개발·수정 시 프로젝트 API 개발 문서 확인** — 아래 이정표에 실제 문서가 등록된 경우 패키지 구조, 에러코드, 구현 완료 목록 확인
3. **주석 필수** — 클래스·메서드 역할, 파라미터, 예외 설명
4. **@Slf4j 로그 필수** — 서비스 레이어에서 주요 흐름 및 경고 로그 추가
5. **API 생성 및 수정 시 테스트코드 항상 함께 작성**
   - Controller·Service 테스트 도구와 mock annotation은 프로젝트의 Spring Boot 버전 및 기존 테스트 패턴을 따름
   - **API 작업 완료 후 아래 항목을 반드시 순서대로 처리하고 마무리**
     - [ ] 변경 계층의 대응 테스트 작성 및 통과 확인
     - [ ] 프로젝트가 사용하는 경우 OpenAPI·Swagger 또는 다른 API 명세 업데이트
     - [ ] 아래 이정표에 등록된 API 구현 현황 문서 업데이트
     - [ ] README.md 업데이트 — 신규 엔드포인트 추가 또는 경로·메서드 변경 시에만 API 목록과 `_last update` 날짜를 함께 업데이트. 응답 필드 추가 등 내부 변경은 업데이트하지 않는다.
6. **API 명세 방식 유지** — 프로젝트가 Swagger interface 분리, annotation 또는 spec-first 방식을 사용 중일 때만 해당 기존 구조를 유지
7. **GET API 파라미터 처리 규칙** — 아래 내용은 프로젝트가 이 규칙을 채택한 경우에만 적용
   - 파라미터가 1개: `@RequestParam`으로 직접 받기
   - 파라미터가 2개 이상: Request 객체(`@Valid`)로 받기
   - Request 객체를 만드는 경우 각 필드에 `@Schema` 추가 (description, example, requiredMode 포함)
8. **Schema annotation** — 프로젝트가 OpenAPI annotation을 사용 중일 때만 기존 DTO 작성 규칙에 맞춰 추가
9. **import 문 사용 원칙** — 새로운 클래스 타입 참조 시 반드시 `import` 문에 추가. 이름 충돌 등 예외적인 경우에만 FQN 사용 허용
10. **예외 클래스 통일** — 비즈니스 예외 발생 시 프로젝트에서 정한 단일 예외 클래스를 사용 (`[ProjectException]` ← 프로젝트에서 직접 명명)
11. **테이블 변경 시 문서 동기화** — DDL 문서가 이정표에 등록된 프로젝트에서는 실제 migration과 함께 업데이트
12. **프로젝트 Context 최신화** — 아래 이정표에 등록된 문서가 있으면 신규 API, 파일, 설계 결정 변경을 동기화

---

## Spring API Skill 라우팅

- 신규 Spring MVC REST API 추가 → `spring-api-create`
- 기존 API의 경로·메서드·요청·응답·검증·동작 변경 → `spring-api-update`
- 기존 API 제거·폐기 → `spring-api-delete`
- 새 endpoint로 기존 endpoint를 대체하는 혼합 변경 → `spring-api-update`를 주 Workflow로 사용하고 생성·삭제 확인을 함께 수행
- WebFlux·Kotlin·GraphQL·R2DBC 중심 작업 → 1차 Skill 범위 밖임을 알리고 임의 적용하지 않음

각 Skill은 이 파일의 프로젝트 고유 규칙과 참고 문서 이정표를 우선하고, 기존 Controller→Service→데이터 접근 구조를 유지한다.

---

## 프로젝트 커스텀 규칙 (아래에 추가)

> 이 섹션에 프로젝트 고유 규칙을 추가한다.
> 예시: ORM 사용 방식, 에러코드 체계, 인증 방식, 도메인별 특이사항 등

---

## 참고 문서 이정표

> 아래 표를 프로젝트 문서 구조에 맞게 채운다.

| 상황 | 읽을 파일 |
|---|---|
| API 개발·수정 시 | `[프로젝트 API 개발 문서 경로]` |
| DB 스키마 확인 시 | `[프로젝트 DDL·migration 문서 경로]` |
| API 명세 확인 시 | `[프로젝트 API 명세 경로 — 사용하는 경우]` |
| 배포·운영 작업 시 | `[프로젝트 배포 문서 경로]` |
| Git push·PR 시 | remote: `[SSH 원격 주소]` |