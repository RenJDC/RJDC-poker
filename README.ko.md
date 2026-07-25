# RJDC-Poker — 매직 포커

> [!WARNING]
> 이 문서는 대규모 언어 모델(AI)에 의해 번역되었습니다. 번역에 부정확한 내용이 포함될 수 있습니다. 정확한 정보는 [중국어 버전](README.md)을 참조하시기 바랍니다.

[Wombat_Magic_Poker](https://github.com/HuaweiREN/Wombat_Magic_Poker)에서 포크한 프로젝트로, Android 휴대폰에 최적화되어 있으며 기본적으로 클래식 매직 스와이프 모드를 사용합니다.

**원작자**: [HuaweiREN](https://github.com/HuaweiREN) — [Wombat_Magic_Poker](https://github.com/HuaweiREN/Wombat_Magic_Poker)

**포크 작성자**: [RenJDC](https://github.com/RenJDC)

---

## ✨ 기능

### 효과

실행하면 화면이 **완전히 검게** 표시되며 버튼이나 텍스트가 전혀 없습니다 — 이는 마술 공연의 사실감을 위한 의도적인 디자인입니다. 관객은 휴대폰에서 어떤 이상한 점도 알아채지 못합니다.

### 사용 방법

1. **랭크 선택**: 15개의 그리드 셀(3열 × 5행)을 탭하여 랭크(A–K, 스몰 조커, 빅 조커)를 선택합니다

   ```
   ┌─────┬─────┬─────┐
   │  A  │  2  │  3  │
   ├─────┼─────┼─────┤
   │  4  │  5  │  6  │
   ├─────┼─────┼─────┤
   │  7  │  8  │  9  │
   ├─────┼─────┼─────┤
   │ 10  │  J  │  Q  │
   ├─────┼─────┼─────┤
   │  K  │ 소조 │ 대조 │
   └─────┴─────┴─────┘
   ```
2. **슈트 선택**: 랭크 선택 후 화면 **아무 곳에서나 스와이프**하여 슈트를 선택합니다
   - ⬆️ **위로 스와이프** = 스페이드 &nbsp;&nbsp; ➡️ **오른쪽으로 스와이프** = 하트
   - ⬇️ **아래로 스와이프** = 클럽 &nbsp;&nbsp; ⬅️ **왼쪽으로 스와이프** = 다이아
3. 해당하는 플레잉 카드 이미지가 즉시 표시됩니다
4. **대기 화면으로 돌아가기**: 카드 이미지를 탭하면 완전히 검은 대기 화면으로 돌아갑니다

### 특수 조작

- **스몰 조커 / 빅 조커**: 그리드 하단 중앙/오른쪽 셀을 탭하면 스와이프 없이 바로 카드가 표시됩니다
- **실수 터치 방지**: 8px 미만의 스와이프는 무시됩니다. 필요한 경우 다시 스와이프하세요

## 📱 다운로드

APK는 [Releases](../../releases)에서 다운로드하거나 소스에서 직접 빌드하세요.

## 🛠️ 빌드

```bash
flutter pub get
flutter build apk --release
```

> 중국 내 네트워크 사용자는 미러를 설정하세요:
> ```bash
> export PUB_HOSTED_URL=https://pub.flutter-io.cn
> export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
> ```

## 🔧 원본과의 차이점

- 기본 모드를 `GridSwipeCardSelector`(클래식 매직 스와이프 모드)로 변경
- 상호작용을 **2단계 방식**으로 변경: 탭하여 랭크 선택 → 스와이프하여 슈트 선택
- 방향 감지에 `|dx| > |dy|` 절대값 비교 사용, 대각선 스와이프로 잘못된 슈트가 선택되지 않음
- 음성 관련 종속성 제거(`sherpa_onnx`, `flutter_sound`, `permission_handler` 등)
- 음성 모델 에셋 제거, APK 크기 ~70MB에서 ~29MB로 감소
- 대기 화면에서 돌아온 후 첫 번째 탭이 무시되는 문제 수정

## 📁 프로젝트 구조

```
lib/
├── main.dart                  # 진입점: 앱 초기화, 대기/표시 상태 관리
├── card_selector.dart         # CardSelector 추상 인터페이스
├── grid_swipe_selector.dart   # 매직 모드: 탭 → 스와이프
└── custom_selector.dart       # 기타 선택기 (미사용, 참고용)

android/app/src/main/
└── AndroidManifest.xml        # Android 설정: 앱 이름, 권한

assets/
└── images/                    # 플레잉 카드 이미지 (heitao_A.png, hongtao_5.png 등)

pubspec.yaml                   # 프로젝트 설정: 종속성, 에셋, 버전
```

## 🙏 감사의 말

- **원작자** [HuaweiREN](https://github.com/HuaweiREN)님과 그의 [Wombat_Magic_Poker](https://github.com/HuaweiREN/Wombat_Magic_Poker) 프로젝트
- Bilibili [**barry巴里里**](https://space.bilibili.com/your-uid)님의 비디오 컨셉에서 영감을 받음
- 카드 이미지 에셋 제공처 [GitCode](https://gitcode.com/open-source-toolkit/77d38/)

## 📄 라이선스

듀얼 라이선스:

- **원본 코드**(Wombat_Magic_Poker): [MIT License](LICENSE) — Copyright (c) 2026 HuaweiREN
- **수정 및 추가 코드**(RenJDC): [GNU General Public License v3.0](LICENSE-GPLv3)

수정된 버전을 사용할 경우 GPLv3의 오픈소스 요구사항을 준수해야 합니다.
