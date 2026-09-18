# Mecha hangar

Godot 4.7 프로젝트. F6으로 `scenes/mecha_hangar.tscn`을 실행하거나 F5로 프로젝트를 실행합니다.

에반게리온 격납고 레퍼런스의 대칭 정비 발판, 전면 다리, 올리브색 패널 벽, 적색 경고등, 청록색 후면 조명과 청색 도크 수면을 구성했습니다. 로봇은 기존 `TripoModels/mecha_robot_3d_model/mecha_robot_3d_model.fbx`를 인스턴스로 연결했습니다.

## 조작

- `WASD` / 방향키: 플레이어 이동 (현재 카메라 기준)
- `Shift`: 플레이어 달리기

- `1`: 기본 정면 구도
- `2`: 사선 구도
- `3`: 상단 구도
- `P`: PSX 화면 효과 켜기 / 끄기
- `T`: 틸트 시프트 렌즈 효과 켜기 / 끄기
- 마우스 오른쪽 버튼을 누른 채 `WASD`: 카메라 이동, 마우스: 시선 회전
- `Q` / `E`: 카메라 로컬 아래 / 위, `Shift`: 빠르게 이동
- `R`: 현재 카메라 원위치, `Esc`: 마우스 해제

## 편집

씬 트리의 01~09 그룹에서 도크, 벽, 플랫폼, 정비 암, 로봇, 소품, 작업자, 조명, 카메라를 개별 수정할 수 있습니다. 구조물은 실제로 저장된 메시 노드이며 런타임 생성에 의존하지 않습니다. `scenes/player.tscn`의 2D 스프라이트 플레이어가 앞쪽 다리에서 시작합니다. 이동 범위는 앞쪽 다리와 양옆 통로의 전면 구간으로 제한하며, 전체 구조물의 물리 충돌은 구현하지 않았습니다. 우클릭 카메라 조작 중에는 플레이어가 멈춥니다.

기존 Tripo 씬과 FBX 파일은 보존했습니다. 격납고 FBX 내부의 연결 성분 106개를 `TripoModels/hangar_separated/hangar_loose_parts.glb`로 분리했으며, 원래 UV와 텍스처를 유지했습니다. 이 중 벽, 플랫폼, 정비 암, 도어, 호스, 드럼통, 상자, 경고등, 제어함을 현재 씬에 재사용했습니다. 각 메시의 `source_part` 메타데이터와 노드 이름으로 원본 조각 번호를 확인할 수 있습니다.

큰 배치와 구조 지지대, 난간, 도크 바닥은 기존 구성입니다. 로봇은 기존 FBX의 텍스처를, 추출한 환경 부품은 원본 격납고 텍스처 아틀라스를 사용합니다. 이전에 코드로 생성했던 표면 노이즈 텍스처는 제거했습니다. 원본 부품은 방향과 크기를 조정했으며, 생성 메시의 비뚤어진 외형을 일부 유지했습니다.

PSX 표현은 최근접 텍스처 필터, 무광 재질, 화면상 640×480 픽셀 격자, 채널별 32단계 색상과 약한 디더링으로 구성했습니다. 실제 3D 렌더 해상도를 낮추는 방식은 아니며, 화면 셰이더가 픽셀 격자를 표현합니다. `P`로 화면 효과만 비교할 수 있고, 에디터에서는 `10_PSXPresentation`의 표시 여부나 `shaders/psx_display.gdshader`의 파라미터로 조정할 수 있습니다.

`tools/build_hangar.gd`는 배치 생성 원본입니다. 아래 명령은 **저장된 격납고 씬을 다시 생성하므로 에디터에서 직접 수정한 내용은 덮어씁니다.**

```sh
godot --headless --path . --script tools/build_hangar.gd
```

미리보기 갱신: `godot --path . --script tools/capture_hangar.gd`.

틸트 시프트 효과는 `11_TiltShift/LensBlur`에서 적용합니다. 로봇이 있는 중앙 띠는 선명하게 유지하고 화면 상하단으로 갈수록 부드럽게 흐려지는 화면 공간 효과입니다. `shaders/tilt_shift.gdshader`의 `focus_center`(초점 높이), `focus_half_width`(선명한 띠의 반폭), `falloff`(전환 폭), `tilt`(띠 기울기), `blur_amount`(흐림 강도)를 조정할 수 있습니다. PSX 처리 뒤에 적용하며 `P`와 `T`로 각각 비교할 수 있습니다. 씬 재생성 시에도 유지됩니다.

선명한 띠는 화면 높이의 44%로 넓혀 흐림 범위를 가장자리로 줄였습니다. `HangarAtmosphere`의 Environment에 청록빛 볼류메트릭 안개를 적용하고, `08_Lighting/GodRayLeft`와 `GodRayRight`의 그림자 지원 스포트라이트로 위에서 내려오는 빛줄기를 표현합니다. 안개 농도는 `volumetric_fog_density`, 빛줄기 강도는 각 조명의 `light_volumetric_fog_energy`, 폭은 `spot_angle`로 조정합니다. 기존 조명의 안개 기여도는 낮춰 전체가 밝게 뜨는 것을 줄였습니다. Forward+ 렌더러를 사용하며 씬 생성 원본에도 동일하게 반영했습니다.

단색으로 남던 기둥·보·난간·플랫폼 측면에는 `shaders/atlas_surface.gdshader`를 적용했습니다. 원본 Tripo 아틀라스의 금속 패널 구역을 직접 샘플링하여 기존 색상에 명암 질감을 입힙니다. 월드 좌표 기준으로 반복하므로 긴 구조물에서도 질감이 늘어나지 않으며, `atlas_region`, `tiles_per_meter`, `texture_strength`로 범위·크기·강도를 조정할 수 있습니다. 원본 텍스처 파일 자체는 수정하지 않았습니다.

`PurplePitFloor`에는 `shaders/pit_water.gdshader`의 청색 수면 재질을 적용했습니다. 월드 좌표 기반 잔물결, 부드럽게 변형되는 두 겹의 청록색 코스틱 무늬와 움직이는 표면 노멀을 사용합니다. 기존 메시 위치와 크기를 유지하며, 불투명 수면으로 표현합니다. 재질의 `wave_speed`, `wave_scale`, `normal_strength`, `highlight_strength`, `ripple_center`와 세 가지 색상을 조정할 수 있습니다. 씬 재생성 시에도 수면 재질이 적용됩니다.

플레이어는 `sprites/player`에 압축 해제한 8방향 Idle / Walking 에셋을 사용합니다. 정지 시 대기 애니메이션, 이동 시 8방향 걷기 애니메이션을 재생합니다. Shift 달리기 시 재생 속도도 빨라지며, 통로 경계에 막혀 멈추면 대기 상태로 돌아갑니다. `scripts/player.gd`의 속도와 이동 범위, 플레이어 씬의 `pixel_size`로 크기를 조정할 수 있습니다.
