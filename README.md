# 🔧 Verilog Embedded System

본 프로젝트는 **FPGA 기반 임베디드 시스템 설계**를 목표로 하여, **Verilog HDL**을 사용해 다양한 하드웨어 모듈을 직접 구현하고 이를 통합한 시스템입니다. 

주요 목표는 단순한 개별 기능 구현을 넘어, 여러 하드웨어 블록(시계/스톱워치, 초음파 센서, 온습도 센서, UART 통신)을 **하나의 임베디드 시스템으로 통합**하는 경험을 목표로 합니다.

---

## 🧑‍💻 프로젝트 개요

| 항목          | 내용                                     |
|---------------|------------------------------------------|
| **팀원**      | 박승헌, 서윤철, 권희식, 오정일            |
| **진행 기간** | 2025.05.19 ~ 2025.06.02                  |
| **개발 환경** | Vivado, VSCode                           |
| **언어**      | Verilog HDL                              |
| **플랫폼**    | Basys3 FPGA Board                        |
| **센서**      | HC-SR04(초음파 센서), DHT11(온습도 센서)  |
| **역할**      | DHT11 온습도 센서: 박승헌                 |
|               | UART 및 통합: 서윤철                      |
|               | HC-SR04 초음파 센서: 권희식               |
|               | WATCH_STOPWATCH: 오정일                   |

---

## 📁 주요 모듈 설명

| 모듈               | 설명                                                                 |
|--------------------|----------------------------------------------------------------------|
| 🎛 `CU` (Control Unit) | 버튼·스위치·UART 입력을 받아 전체 시스템(CLOCK, SR04, DHT11)을 제어하고, 모드 선택 및 출력 신호(FND, LED, UART)를 관리 |
| ⏱ `CLOCK`         | Stopwatch + Watch 기능. 시간 측정·설정 및 알람(`o_cuckoo`) 기능 포함, FND와 LED 출력 제어 |
| 📏 `SR04`          | HC-SR04 초음파 센서 제어. `trig` 신호 생성 및 `echo` 측정 → 거리(cm) 계산 후 FND·UART 출력 |
| 🌡️ `DHT11`         | DHT11 온습도 센서 통신 FSM. 단일버스 프로토콜로 40bit 데이터 수신, 유효성 검증 후 FND·UART 출력 |
| 📦 `FIFO`          | 센서 데이터(UART) 전송용 버퍼. 거리/온습도 측정값을 ASCII 변환 후 UART로 안정적으로 송신 |
| 🔘 `BtnDebounce`   | 버튼 입력 노이즈 제거 및 안정적인 상승/하강 에지 신호 생성 |
| 🔀 `MUX`           | CLOCK, SR04, DHT11 모듈의 출력(FND, LED, UART) 중 현재 선택된 모드에 따라 최종 출력 경로 선택 |
| 📟 `FND Controller`| 입력된 데이터(시간, 거리, 온습도)를 자리 분할 후 스캔 제어 방식으로 7-Segment(FND)에 표시 |

---

---

### 🧩 Top Schematic
아래 그림은 Vivado에서 생성한 **Top-Level RTL Schematic**입니다.  
Control Unit(CU), 버튼 디바운싱, CLOCK, SR04, DHT11, FIFO, FND Controller 등이 실제로 연결된 구조를 시각적으로 확인할 수 있습니다.  

<p align="center">
  <img src="https://github.com/shhhhhhh1799/Image/blob/main/Top.png" alt="RTL Schematic" width="900"/>
</p>

---

## 1️⃣ ⏱ Stopwatch / Watch 시스템

### ✅ 주요 기능
- `sw[1]` 스위치를 통해 **스톱워치**와 **시계** 모드 전환
- 시계 모드에서 `btnL`, `btnR`로 시/분/초 설정 항목 선택 가능
- 설정 항목 선택 후 `btnU`, `btnD`로 시간 조정 가능
- FND를 통해 시간 출력 (시:분 또는 분:초)

### ⌨️ 입력 핀 설명
| 입력       | 설명                                    |
|------------|-----------------------------------------|
| `clk`      | 시스템 클록 (예: 100MHz)                |
| `rst`      | 전체 시스템 리셋                         |
| `btnL`     | 스톱워치: Clear, 시계: 항목 왼쪽 이동    |
| `btnR`     | 스톱워치: Run/Stop, 시계: 항목 오른쪽 이동 |
| `btnU/D`   | 시계 모드에서 값 증가/감소               |
| `sw[1:0]`  | sw[1]: 모드 선택, sw[0]: 표시 모드 선택  |

### 💡 출력 핀 설명
| 출력       | 설명                                      |
|------------|-------------------------------------------|
| `fnd_data` | 7-Segment (8비트) 표시 데이터              |
| `fnd_com`  | FND 자리 선택 (4비트 공통 단자 제어)       |
| `led[3:0]` | 현재 모드 또는 설정 상태 표시              |

### 🧩 Watch Schematic
아래 그림은 Vivado에서 생성한 **Watch(시계) RTL Schematic**입니다.  
버튼 디바운싱(`BTN*_DB`)을 통해 안정화된 입력 신호가 `WATCH Control Unit`으로 전달되며,  
시/분/초 설정 및 증가·감소 신호가 `STOPWATCH/Watch DP` 모듈로 연결되어 FND에 출력되는 구조를 보여줍니다.  

<p align="center">
  <img src="https://github.com/shhhhhhh1799/Image/blob/main/Watch.png" alt="RTL Schematic" width="900"/>
</p>

### ✨ 특징
- **버튼 디바운스 처리**: `btnL`, `btnR`, `btnU`, `btnD` 각각 독립 모듈로 안정화 처리  
- **Watch CU**: 시/분/초 설정 제어 신호(`o_set_hour`, `o_set_min`, `o_set_sec`) 생성  
- **STOPWATCH/Watch DP**: 설정된 신호 기반으로 카운트 동작 수행, `hour:min:sec` 출력  
- **LED 출력**: 현재 선택된 모드/상태를 LED로 확인 가능  

### 🧩 Stopwatch Schematic
아래 그림은 Vivado에서 생성한 **Stopwatch(스톱워치) RTL Schematic**입니다.  
버튼 입력(`btnR_RunStop`, `btnL_Clear`)이 디바운싱 처리(`BTN*_DB`)를 거쳐 안정화된 후,  
`STOPWATCH Control Unit`이 이를 해석하여 **시간 카운트 제어**를 수행하고, `STOPWATCH_DP` 모듈을 통해 `hour:min:sec:msec` 값이 출력되는 구조입니다.  

<p align="center">
 <img src="https://github.com/shhhhhhh1799/Image/blob/main/Stopwatch.png" alt="RTL Schematic" width="900"/>
</p>

### ✨ 특징
- **버튼 디바운스 처리**: `btnR_RunStop`, `btnL_Clear` → 안정적인 제어 신호 생성  
- **Stopwatch CU**: 시작/정지(run_stop), 초기화(clear) 제어 신호 생성  
- **Stopwatch DP**: 밀리초(ms) 단위까지 카운트 → 초, 분, 시 단위로 누적 출력  
- **출력**: `hour:min:sec:msec` 값이 FND/LED로 전달되어 실시간 표시  

### 🧪 예시 시나리오
- `sw[1]=1`: 스톱워치 모드
  - `btnR`: 시작/정지
  - `btnL`: 시간 초기화
- `sw[1]=0`: 시계 모드
  - `btnL/btnR`: 시/분/초 항목 선택
  - `btnU/btnD`: 시간 설정 (증가/감소)

---

## 2️⃣ 📏 초음파 거리 측정 시스템

### ✅ 주요 기능
- HC-SR04 초음파 센서를 이용한 거리 측정
- 측정된 값을 FND로 출력 + UART로 전송
- 버튼을 눌러 측정 시작 가능

### 📦 하드웨어 구성
- 초음파 센서: **HC-SR04**
- 입력: `btn_start`, `echo`
- 출력: `trig`, `tx`, `fnd_data`, `fnd_com`

### ⌨️ 입력 및 출력 설명
| 핀 이름     | 설명                              |
|------------|-----------------------------------|
| `btn_start`| 측정 시작 버튼                     |
| `echo`     | 초음파 센서 echo 신호 입력         |
| `trig`     | 초음파 센서 trigger 신호 출력      |
| `fnd_data` | 거리 값 표시용 FND 데이터 출력     |
| `tx`       | UART 송신선                        |
| `rx`       | UART 수신선 (미사용 시 GND 연결)   |

### 🧩 HC-SR04 Schematic
아래 그림은 Vivado에서 생성한 **HC-SR04 초음파 센서 RTL Schematic**입니다.  
센서 입력(`echo`)과 트리거(`trig`) 신호를 처리하는 `SR04 Controller`를 중심으로,  
거리 계산 결과가 **HEX 변환 → UART 송신 → FND 표시** 흐름으로 연결되는 구조를 보여줍니다.  

<p align="center">
  <img src="https://github.com/shhhhhhh1799/Image/blob/main/HC-SR04.png" alt="RTL Schematic" width="900"/>
</p>

### 🧪 UART 출력 예시
거리(cm): 1.23

---

## 3️⃣ 🌡️ DHT11 온습도 측정 시스템

### ✅ 주요 기능
- UART 수신으로 `'s'` 문자 받으면 측정 시작
- DHT11 센서에서 온도 / 습도 수집
- UART로 메시지 전송 + FND로 표시
- 센서 통신은 10us 기반의 FSM으로 설계

### 📦 하드웨어 구성
- 센서: **DHT11**
- UART: 송수신 모두 사용
- 출력: FND (온도 2자리 + 습도 2자리)

### ⌨️ 핀 구성
| 핀 이름      | 설명                               |
|-------------|------------------------------------|
| `rx`        | UART 수신 (`'s'` 신호)              |
| `tx`        | UART 송신                           |
| `dht11_io`  | DHT11 양방향 데이터 핀              |
| `fnd_data`  | FND 출력                            |
| `LED`       | 측정 유효 시 점등                   |
| `state_led` | FSM 상태 디버깅용 LED               |

### 🧩 DHT11 Schematic
아래 그림은 Vivado에서 생성한 **DHT11 온습도 센서 RTL Schematic**입니다.  
DHT11 센서에서 수집한 **온도/습도 데이터**가 FSM 기반 컨트롤러(`U_DHT11`)를 통해 처리되고,  
이 값이 **HEX 변환 → UART 송신 → FND 표시** 흐름으로 전달되는 구조를 보여줍니다.  

<p align="center">
  <img src="https://github.com/shhhhhhh1799/Image/blob/main/DHT11.png" alt="RTL Schematic" width="900"/>
</p>

### 🧪 UART 출력 메시지 예시
```
Temp = 25C
Humi = 43%
```

---

## 4️⃣ 🛰 UART 통신 시스템

### ✅ 주요 기능
- **Tx/Rx 지원 (115200bps, 8N1)**: 시작 비트 – 데이터 8bit – 정지 비트 프레임 구조
- **FIFO 버퍼**: 거리 및 온습도 측정 데이터를 안전하게 UART로 전송
- **명령 파서**: 수신 문자열을 해석해 제어 신호 생성  
  (예: `RESET`, `CLEAR`, `R/S`, `SR`, `DHT`, `UP`, `DOWN`)
- **ASCII 변환**: 수치 데이터를 **HEX → ASCII** 코드로 변환하여 문자열 출력
- **모듈 연동**: Stopwatch, Watch, SR04, DHT11 모듈의 결과를 UART로 통합 전송

### 📦 하드웨어 구성
- FIFO 버퍼, HEX-to-ASCII 변환기, UART 송수신기(UART Tx/Rx)
- Control Unit과 연결되어 외부 명령 입력 및 내부 제어 신호 동기화

### ⌨️ 핀 구성
| 핀 이름      | 방향 | 설명                               |
|--------------|------|------------------------------------|
| `clk`        | In   | 시스템 클록 (예: 100MHz)            |
| `rst`        | In   | 비동기 리셋                         |
| `rx`         | In   | UART 수신                           |
| `tx`         | Out  | UART 송신                           |
| `tx_din[7:0]`| In   | 송신 데이터 입력 (FIFO enqueue)     |
| `push_tx`    | In   | 송신 데이터 유효 신호               |
| `tx_busy`    | Out  | 송신 중 상태                        |
| `tx_done`    | Out  | 전송 완료 펄스                      |

### 🖥 UART 동작 예시

아래 그림은 **PC에서 UART 통신 테스트 프로그램(ComPortMaster)**을 사용하여  
FPGA 보드와 송·수신 테스트를 진행한 화면입니다.  

왼쪽은 **거리 측정 결과 (Distance)**가 출력된 예시이고,  
오른쪽은 **온습도 측정 결과 (Temp/Humi)**가 출력된 예시입니다.  
또한, 상단 Quick Send 기능을 통해 `RESET`, `CLEAR`, `R/S`, `SR`, `DHT`, `UP`, `DOWN` 명령을 직접 전송하여  
FPGA 내부 모듈을 제어할 수 있습니다.  

<p align="center">
  <img src="https://github.com/shhhhhhh1799/Image/blob/main/Uart_example.png" alt="RTL Schematic" width="900"/>
</p>

---

## 🔚 마무리

본 프로젝트는 FPGA 기반의 디지털 시계, 센서 기반 데이터 측정, UART 통신, FND 디스플레이 등 **임베디드 시스템 설계에 필요한 핵심 기술을 통합적으로 구현**한 결과물입니다.

이를 통해 FSM 설계, 타이밍 제어, 시리얼 통신, 센서 연동 등에 대한 실습을 직접 수행할 수 있으며,  
향후 **무선 통신, IoT 연동, OLED 디스플레이** 등의 확장 프로젝트로도 발전이 가능합니다.

## 📹 시연 영상  
👉 [블로그에서 시연 영상 보기](https://blog.naver.com/PostView.naver?blogId=sssssssh17&Redirect=View&logNo=223931104573&categoryNo=1&isAfterWrite=true&isMrblogPost=false&isHappyBeanLeverage=true&contentLength=3619)
