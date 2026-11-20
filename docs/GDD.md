# وثيقة تصميم اللعبة (GDD): Orbit Leap
**المنصة:** Mobile (Android / iOS) – الوضع الرأسي (Portrait)  
**المحرك المعتمد:** Godot 4.3 (Compatibility Renderer / GLES3)  
**النوع:** One-Touch Hyper-Casual / Arcade  
**الجمهور المستهدف:** لاعبو ألعاب الموبايل السريعة (Session length: 30–90 ثانية)

---

## 1. حلقة اللعب الأساسية (Core Gameplay Loop)

```text
[شاشة البداية / نقرة فورية]
        │
        ▼
[دوران القمر حول الكوكب الحالي] ──(الانتظار طويلاً = انهيار الكوكب)──► [خسارة]
        │
        ▼ (نقرة واحدة Tap)
[إفلات مماسي والانطلاق في الفضاء]
        │
   ┌────┴───────────────────────────┐
   ▼                                ▼
[اصطدام بعائق / فضاء فارغ]     [التقاط بواسطة الكوكب التالي]
   │                                │
   ▼                                ▼
[Game Over + Shake]           [+1 نقطة / تفعيل Combo + Snap to Orbit]
   │                                │
   └──────────◄ (إعادة فورية) ───────┘
```

---

## 2. ميكانيكا التحكم والفيزياء (Mechanics & Physics Math)

لضمان الدقة والاستجابة اللحظية على شاشات المحمول المختلفة، **لا نعتمد على محرك الفيزياء الصلبة (RigidBody)**، بل نستخدم معادلات متجهة مباشرة عبر `Area2D` مدمجة مع `delta`.

### أ. حالات اللاعب (Player State Machine)
* `STATE_ORBITING`: يدور حول مركز الكوكب بنصف قطر ثابت $R$.
* `STATE_FLYING`: ينطلق في خط مستقيم بالسرعة المتجهة المماسية لحظة الإفلات.
* `STATE_DEAD`: توقف التحكم، تشغيل الجزيئات وشاشة الموت.

### ب. المعادلات الرياضية الدقيقة

```text
1. الدوران (Orbiting):
   Angle += OrbitSpeed * Direction * delta
   Position.x = Planet.Position.x + cos(Angle) * OrbitRadius
   Position.y = Planet.Position.y + sin(Angle) * OrbitRadius

2. لحظة الإفلات (Release Vector - Tangent):
   // زاوية المماس عمودية على نصف القطر
   TangentAngle = Angle + (PI / 2) * Direction
   Velocity = Vector2(cos(TangentAngle), sin(TangentAngle)) * LaunchSpeed

3. الالتقاط (Capture Radius):
   if Distance(Player.Position, NextPlanet.Position) <= NextPlanet.CaptureRadius:
       Angle = (Player.Position - NextPlanet.Position).Angle()
       SwitchState(STATE_ORBITING)
```

### ج. محددات السرعة والأبعاد (Screen Reference: 1080 × 1920)
| المعامل | القيمة الابتدائية | الوصف |
| :--- | :--- | :--- |
| `LaunchSpeed` | `1800 px/s` | سرعة انطلاق الصاروخ في الفراغ. |
| `OrbitSpeed` | `3.5 rad/s` | سرعة الدوران الزاوي حول الكوكب. |
| `BaseOrbitRadius` | `140 px` | المسافة بين مركز الكوكب والقمر. |
| `CaptureRadius` | `200 px` | نصف قطر حقل الجاذبية المخصص للالتقاط. |
| `MaxOrbitTime` | `3.0 ثوانٍ` | أقصى مدة للبقاء بالمدار قبل انهيار الكوكب (Anti-camping). |

---

## 3. التوليد الإجرائي وموازنة الصعوبة (Procedural Gen & Scaling)

يتم توليد الكواكب رأسياً للأعلى بشكل لا نهائي، مع إلغاء تفريغ الكواكب القديمة لتوفير الذاكرة (Object Pooling).

### أ. قواعد التوليد (Spawning Rules)
* **المسافة الرأسية بين كوكبين ($Y$-Distance):** تتراوح بين `400px` و `650px`.
* **الإزاحة الأفقية ($X$-Offset):** تتراوح بين `-300px` و `+300px` عن منتصف الشاشة (مع إبقاء الكوكب كاملاً داخل الـ Viewport).
* **اتجاه الدوران (Direction):** عشوائي (`1` لاتجاه عقارب الساعة، `-1` لعكس عقارب الساعة).

### ب. منحنى التصاعد (Difficulty Curve)

| النقاط (Score) | التحديات الجديدة المضافة | تأثير الصعوبة |
| :--- | :--- | :--- |
| **0 – 5** | كواكب ثابتة، مسافات قريبة ($400\text{px}$)، $R$ كبير ($150\text{px}$). | مرحلة التعلم والاستيعاب. |
| **6 – 15** | كواكب تتحرك أفقياً بتردد جيبي (Sine wave). | تدريب التوقيت (Timing). |
| **16 – 30** | كواكب تصغر تدريجياً، حقول جاذبية أصغر ($CaptureRadius = 160\text{px}$). | تقليل هامش الخطأ. |
| **31+** | إضافة كويكبات عائمة كعوائق بين المدارات تدور في مسارات متقاطعة. | تفادي العوائق أثناء الطيران. |

---

## 4. الهيكل البرمجي داخل Godot 4.3 (Implementation Architecture)

### أ. شجرة العقد (Node Tree Hierarchy)

```text
Main (Node2D)
├── Camera2D (تتبع اللاعب عمودياً فقط بسلاسة / Lerp)
├── PlanetSpawner (Node2D) -> يدير Object Pool للكواكب
├── Player (Area2D)
│   ├── Sprite2D
│   ├── CollisionShape2D (Circle: Radius = 12px)
│   └── Trail2D (Line2D للذيل البصري)
├── ObstacleContainer (Node2D)
├── UILayer (CanvasLayer)
│   ├── HUD (Score, HighScore, ComboText)
│   └── GameOverPanel
└── JuiceManager (Node) -> Screen Shake & Sounds
```

### ب. كود النواة البرمجية: `Player.gd`

```gdscript
class_name Player
extends Area2D

enum State { ORBITING, FLYING, DEAD }

@export var launch_speed: float = 1800.0
@export var base_orbit_speed: float = 3.5

var current_state: State = State.ORBITING
var current_planet: Node2D = null
var orbit_angle: float = 0.0
var orbit_direction: float = 1.0
var orbit_radius: float = 140.0
var velocity: Vector2 = Vector2.ZERO
var orbit_timer: float = 0.0
const MAX_ORBIT_TIME: float = 3.0

signal score_increased(points: int)
signal player_died

func _ready() -> void:
	area_entered.connect(_on_area_entered)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("tap") and current_state == State.ORBITING:
		launch()

func init_orbit(planet: Node2D, direction: float = 1.0) -> void:
	current_planet = planet
	orbit_direction = direction
	orbit_radius = planet.get("orbit_radius") if "orbit_radius" in planet else 140.0
	orbit_angle = (global_position - planet.global_position).angle()
	orbit_timer = 0.0
	current_state = State.ORBITING

func launch() -> void:
	current_state = State.FLYING
	var tangent_angle: float = orbit_angle + (PI / 2.0) * orbit_direction
	velocity = Vector2(cos(tangent_angle), sin(tangent_angle)) * launch_speed
	current_planet = null

func _process(delta: float) -> void:
	match current_state:
		State.ORBITING:
			process_orbit(delta)
		State.FLYING:
			process_flight(delta)
		State.DEAD:
			pass

func process_orbit(delta: float) -> void:
	if not is_instance_valid(current_planet):
		die()
		return
		
	orbit_timer += delta
	if orbit_timer >= MAX_ORBIT_TIME:
		die() # عقاب عدم الإفلات والانتظار الطويل
		return

	orbit_angle += base_orbit_speed * orbit_direction * delta
	global_position = current_planet.global_position + Vector2(cos(orbit_angle), sin(orbit_angle)) * orbit_radius

func process_flight(delta: float) -> void:
	global_position += velocity * delta

func _on_area_entered(area: Area2D) -> void:
	if current_state != State.FLYING:
		return

	if area.is_in_group("Planets"):
		init_orbit(area, -orbit_direction) # عكس اتجاه الدوران لإضفاء حيوية
		score_increased.emit(1)
	elif area.is_in_group("Hazards"):
		die()

func die() -> void:
	current_state = State.DEAD
	player_died.emit()
	queue_free()
```

---

## 5. العصير البصري والصوتي (Juice & Feedback)

لتحويل الميكانيكا البسيطة إلى لعبة إدمانية، تُطبق الاستجابات الشعورية التالية بدقة:

1. **الاهتزاز الكاميرا (Screen Shake):**
   * عند الإفلات: اهتزاز خفيف جداً (`Strength = 4px, Duration = 0.08s`).
   * عند الالتقاط الناجح: نبضة سريعة (`Strength = 8px, Duration = 0.12s`).
   * عند الموت: اهتزاز قوي مع خمود تدريجي (`Strength = 25px, Duration = 0.4s`).
2. **تمدد وانضغاط الكواكب (Squash & Stretch):**
   * عند دخول مدار الكوكب، يتم تطبيق `Tween` على مقياس الكوكب ($Scale$): يتسع إلى $(1.15, 0.85)$ ثم يرتد إلى $(1.0, 1.0)$ خلال $0.2$ ثانية.
3. **تأثير الذيل (Trail):**
   * استخدام عقدة `Line2D` مثبتة خلف اللاعب ترسم آخر 15 إطاراً حركياً، مع تدرج شفافية (Gradient Fade) يمنح إحساساً حقيقياً بالسرعة.
4. **نظام الكومبو الصوتي (Dynamic Pitch):**
   * صوت الالتقاط الناجح يرتفع تردده بمقدار نصف درجة موسيقية (Semitone: `pitch_scale += 0.05`) مع كل قفزة متتالية سريعة، ويعود للتردد الأصلي عند التردد أو التباطؤ.

---

## 6. واجهة المستخدم وتوافق شاشات الهواتف (UI & Safe Area)

* **عرض الشاشة الافتراضي (Project Settings):**  
  `width = 1080`, `height = 1920`, `stretch/mode = canvas_items`, `stretch/aspect = expand`.
* **مراعاة الـ Notch والشريط السفلي (Safe Area):**
  * جميع عناصر الـ HUD محصورة داخل حاوية `MarginContainer` تبتعد بمقدار `120px` عن الحافة العلوية و `80px` عن الحافة السفلية.
* **شاشات الواجهة:**
  * **HUD:** يعرض النقطة الحالية بنص عريض بالمنتصف العلوي بخلفية شبه شفافة.
  * **Game Over:** تظهر فوراً بنظام التلاشي (Fade-in 0.2s): تعرض النقاط الحالية، أفضل رقم محلي (Saved via `ConfigFile` / `user://save.cfg`)، وزر "نقرة للإعادة" يغطي الشاشة كاملة