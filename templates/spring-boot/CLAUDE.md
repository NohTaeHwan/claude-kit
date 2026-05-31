# [프로젝트명] — Claude 개발 컨텍스트

## 프로젝트
[프로젝트 한 줄 설명]
- Java 17+, Spring Boot 3.x
- [ORM 선택: JPA / MyBatis 등]
- [DB 선택: MySQL / PostgreSQL 등]
- 패키지 루트: `[com.example.프로젝트]`

---

## 개발 유의사항 (항상 준수)

1. **작업 시작 전 참고 문서 이정표 확인** — 사용자 요청을 받으면 아래 "참고 문서 이정표"를 확인하여 연관된 문서가 있으면 작업 전에 반드시 읽고 시작
2. **API 개발·수정 시 `docs/dev_context.md` 필독** — 패키지 구조, 에러코드, 구현 완료 목록 확인
3. **주석 필수** — 클래스·메서드 역할, 파라미터, 예외 설명
4. **@Slf4j 로그 필수** — 서비스 레이어에서 주요 흐름 및 경고 로그 추가
5. **API 생성 및 수정 시 테스트코드 항상 함께 작성**
   - Controller: `@WebMvcTest` + `@MockitoBean` (`@MockBean` deprecated in Spring Boot 3.4+)
   - Service: `@ExtendWith(MockitoExtension.class)` + `@InjectMocks`
   - 도메인 객체 필드 주입: `ReflectionTestUtils.setField()`
   - **API 작업 완료 후 아래 항목을 반드시 순서대로 처리하고 마무리**
     - [ ] Service 테스트 작성 및 통과 확인
     - [ ] Controller 테스트 작성 및 통과 확인
     - [ ] Swagger 명세 (`*ApiSpecification`) 업데이트
     - [ ] `docs/dev_context.md` 구현 완료 테이블 업데이트
     - [ ] README.md 업데이트 — 신규 엔드포인트 추가 또는 경로·메서드 변경 시에만 API 목록과 `_last update` 날짜를 함께 업데이트. 응답 필드 추가 등 내부 변경은 업데이트하지 않는다.
6. **Swagger 인터페이스 분리** — `*ApiSpecification` 인터페이스에 `@Operation`/`@ApiResponse` 작성, Controller는 implements만
7. **GET API 파라미터 처리 규칙**
   - 파라미터가 1개: `@RequestParam`으로 직접 받기
   - 파라미터가 2개 이상: Request 객체(`@Valid`)로 받기
   - Request 객체를 만드는 경우 각 필드에 `@Schema` 추가 (description, example, requiredMode 포함)
8. **@Schema 필수** — Request/Response DTO 클래스와 모든 필드에 `@Schema(description, example)` 추가
9. **import 문 사용 원칙** — 새로운 클래스 타입 참조 시 반드시 `import` 문에 추가. 이름 충돌 등 예외적인 경우에만 FQN 사용 허용
10. **예외 클래스 통일** — 비즈니스 예외 발생 시 프로젝트에서 정한 단일 예외 클래스를 사용 (`[ProjectException]` ← 프로젝트에서 직접 명명)
11. **테이블 변경 시 문서 동시 수정 필수** — DDL 변경 시 반드시 `docs/create_ddl.md`와 `docs/backend_specification.md`를 함께 업데이트
12. **CLAUDE.md 및 `docs/dev_context.md` 항상 최신화** — 신규 API 추가, 파일 생성·수정, 설계 결정 등 변경이 생길 때마다 즉시 업데이트

---

## 프로젝트 커스텀 규칙 (아래에 추가)

> 이 섹션에 프로젝트 고유 규칙을 추가한다.
> 예시: ORM 사용 방식, 에러코드 체계, 인증 방식, 도메인별 특이사항 등

---

## 참고 문서 이정표

> 아래 표를 프로젝트 문서 구조에 맞게 채운다.

| 상황 | 읽을 파일 |
|---|---|
| API 개발·수정 시 | `docs/dev_context.md` |
| DB 스키마 확인 시 | `docs/create_ddl.md` |
| API 명세 확인 시 | `docs/backend_specification.md` |
| 배포·운영 작업 시 | `docs/deploy_guide.md` |
| Git push·PR 시 | remote: `[SSH 원격 주소]` |