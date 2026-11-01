extends Resource
## Immutable catalogue defaults and pure, warehouse-local appraisal. Runtime lots use deep copies.
const QUALITY_NAMES: Array[String] = ["普通", "优良", "稀有", "珍贵", "典藏", "传世", "至臻"]
const QUALITY_COLORS: Array[Color] = [Color("b4bec6"), Color("79cf8a"), Color("67b9e8"), Color("b799f0"), Color("f0c465"), Color("f27279"), Color("eed4ff")]
const QUALITY_COLOR_NAMES: Array[String] = ["白/灰", "绿", "蓝", "紫", "金", "红", "彩"]
const QUALITY_WEIGHTS: Array[int] = [120, 90, 60, 40, 20, 6, 2]
const RAINBOW_COLORS: Array[Color] = [Color("fa8585"), Color("f3cb6b"), Color("8edca6"), Color("7dcdf4"), Color("bba1fa")]
const GRID_COLUMNS: int = 12
const GRID_ROWS: int = 14
const MIN_LOT_VALUE: int = 2000
const MAX_LOT_VALUE: int = 120000
const TAGS: Array[String] = ["电子产品", "古董", "珠宝", "音乐", "工具", "户外装备", "玩具", "艺术品", "收藏品", "精密器械"]
const RULE_TEXT: String = "同仓同 tag：3 件 +15%，5 件 +30%（取最高档）。多 tag 加成相加，单件最高 +60%。同款按件计数，只增加该 tag 物资的价值；各仓独立，不跨仓累计。"
@export var items: Array[Dictionary] = [
	{
		"kind": "vase",
		"name": "青玉瓷瓶",
		"size": [
			2,
			3
		],
		"quality": 3,
		"value": 1800,
		"tags": [
			"古董",
			"艺术品"
		],
		"compact_premium": false
	},
	{
		"kind": "clock",
		"name": "古董座钟",
		"size": [
			3,
			3
		],
		"quality": 3,
		"value": 2200,
		"tags": [
			"古董",
			"精密器械"
		],
		"compact_premium": false
	},
	{
		"kind": "seal",
		"name": "黄铜印章",
		"size": [
			1,
			1
		],
		"quality": 0,
		"value": 350,
		"tags": [
			"古董",
			"艺术品"
		],
		"compact_premium": false
	},
	{
		"kind": "compass",
		"name": "航海罗盘",
		"size": [
			1,
			1
		],
		"quality": 2,
		"value": 900,
		"tags": [
			"古董",
			"户外装备"
		],
		"compact_premium": false
	},
	{
		"kind": "scroll",
		"name": "山水画卷",
		"size": [
			4,
			1
		],
		"quality": 4,
		"value": 3000,
		"tags": [
			"古董",
			"艺术品"
		],
		"compact_premium": false
	},
	{
		"kind": "radio",
		"name": "老式收音机",
		"size": [
			3,
			2
		],
		"quality": 2,
		"value": 850,
		"tags": [
			"电子产品",
			"古董"
		],
		"compact_premium": false
	},
	{
		"kind": "camera",
		"name": "数码相机",
		"size": [
			2,
			1
		],
		"quality": 3,
		"value": 1900,
		"tags": [
			"电子产品",
			"精密器械"
		],
		"compact_premium": false
	},
	{
		"kind": "console",
		"name": "掌上游戏机",
		"size": [
			2,
			1
		],
		"quality": 2,
		"value": 750,
		"tags": [
			"电子产品",
			"玩具"
		],
		"compact_premium": false
	},
	{
		"kind": "laptop",
		"name": "轻薄笔记本",
		"size": [
			3,
			2
		],
		"quality": 4,
		"value": 2800,
		"tags": [
			"电子产品",
			"精密器械"
		],
		"compact_premium": false
	},
	{
		"kind": "headphones",
		"name": "头戴耳机",
		"size": [
			2,
			2
		],
		"quality": 1,
		"value": 450,
		"tags": [
			"电子产品",
			"音乐"
		],
		"compact_premium": false
	},
	{
		"kind": "gold",
		"name": "典藏金条",
		"size": [
			2,
			1
		],
		"quality": 4,
		"value": 3200,
		"tags": [
			"珠宝",
			"收藏品"
		],
		"compact_premium": false
	},
	{
		"kind": "gem",
		"name": "紫晶原石",
		"size": [
			2,
			2
		],
		"quality": 3,
		"value": 2000,
		"tags": [
			"珠宝",
			"收藏品"
		],
		"compact_premium": false
	},
	{
		"kind": "necklace",
		"name": "珍珠项链",
		"size": [
			1,
			1
		],
		"quality": 2,
		"value": 1100,
		"tags": [
			"珠宝",
			"艺术品"
		],
		"compact_premium": false
	},
	{
		"kind": "ring",
		"name": "银制戒指",
		"size": [
			1,
			1
		],
		"quality": 1,
		"value": 400,
		"tags": [
			"珠宝",
			"收藏品"
		],
		"compact_premium": false
	},
	{
		"kind": "watch",
		"name": "机械腕表",
		"size": [
			1,
			1
		],
		"quality": 4,
		"value": 2900,
		"tags": [
			"珠宝",
			"精密器械"
		],
		"compact_premium": false
	},
	{
		"kind": "guitar",
		"name": "木吉他",
		"size": [
			2,
			6
		],
		"quality": 2,
		"value": 1000,
		"tags": [
			"音乐",
			"艺术品"
		],
		"compact_premium": false
	},
	{
		"kind": "trumpet",
		"name": "黄铜小号",
		"size": [
			3,
			2
		],
		"quality": 3,
		"value": 1700,
		"tags": [
			"音乐",
			"收藏品"
		],
		"compact_premium": false
	},
	{
		"kind": "vinyl",
		"name": "黑胶唱片",
		"size": [
			2,
			2
		],
		"quality": 0,
		"value": 300,
		"tags": [
			"音乐",
			"古董"
		],
		"compact_premium": false
	},
	{
		"kind": "music_box",
		"name": "八音盒",
		"size": [
			2,
			2
		],
		"quality": 3,
		"value": 1600,
		"tags": [
			"音乐",
			"精密器械"
		],
		"compact_premium": false
	},
	{
		"kind": "synth",
		"name": "迷你合成器",
		"size": [
			3,
			2
		],
		"quality": 4,
		"value": 2600,
		"tags": [
			"音乐",
			"电子产品"
		],
		"compact_premium": false
	},
	{
		"kind": "drill",
		"name": "电动手钻",
		"size": [
			2,
			2
		],
		"quality": 2,
		"value": 800,
		"tags": [
			"工具",
			"电子产品"
		],
		"compact_premium": false
	},
	{
		"kind": "wrench",
		"name": "活动扳手",
		"size": [
			1,
			2
		],
		"quality": 0,
		"value": 250,
		"tags": [
			"工具",
			"精密器械"
		],
		"compact_premium": false
	},
	{
		"kind": "microscope",
		"name": "实验显微镜",
		"size": [
			2,
			3
		],
		"quality": 4,
		"value": 2700,
		"tags": [
			"工具",
			"精密器械"
		],
		"compact_premium": false
	},
	{
		"kind": "toolbox",
		"name": "金属工具箱",
		"size": [
			3,
			2
		],
		"quality": 2,
		"value": 950,
		"tags": [
			"工具",
			"户外装备"
		],
		"compact_premium": false
	},
	{
		"kind": "caliper",
		"name": "游标卡尺",
		"size": [
			2,
			1
		],
		"quality": 0,
		"value": 350,
		"tags": [
			"工具",
			"精密器械"
		],
		"compact_premium": false
	},
	{
		"kind": "tent",
		"name": "双人帐篷",
		"size": [
			4,
			2
		],
		"quality": 3,
		"value": 1500,
		"tags": [
			"户外装备"
		],
		"compact_premium": false
	},
	{
		"kind": "lantern",
		"name": "露营提灯",
		"size": [
			2,
			2
		],
		"quality": 1,
		"value": 400,
		"tags": [
			"户外装备",
			"工具"
		],
		"compact_premium": false
	},
	{
		"kind": "binoculars",
		"name": "双筒望远镜",
		"size": [
			2,
			1
		],
		"quality": 2,
		"value": 1050,
		"tags": [
			"户外装备",
			"精密器械"
		],
		"compact_premium": false
	},
	{
		"kind": "backpack",
		"name": "登山背包",
		"size": [
			3,
			4
		],
		"quality": 2,
		"value": 700,
		"tags": [
			"户外装备"
		],
		"compact_premium": false
	},
	{
		"kind": "fishing_rod",
		"name": "复合鱼竿",
		"size": [
			1,
			5
		],
		"quality": 3,
		"value": 1400,
		"tags": [
			"户外装备",
			"工具"
		],
		"compact_premium": false
	},
	{
		"kind": "robot",
		"name": "铁皮机器人",
		"size": [
			1,
			2
		],
		"quality": 2,
		"value": 900,
		"tags": [
			"玩具",
			"古董"
		],
		"compact_premium": false
	},
	{
		"kind": "train",
		"name": "模型火车",
		"size": [
			3,
			1
		],
		"quality": 3,
		"value": 1600,
		"tags": [
			"玩具",
			"收藏品"
		],
		"compact_premium": false
	},
	{
		"kind": "bear",
		"name": "布偶熊",
		"size": [
			2,
			3
		],
		"quality": 0,
		"value": 300,
		"tags": [
			"玩具"
		],
		"compact_premium": false
	},
	{
		"kind": "cube",
		"name": "彩色魔方",
		"size": [
			1,
			1
		],
		"quality": 0,
		"value": 200,
		"tags": [
			"玩具"
		],
		"compact_premium": false
	},
	{
		"kind": "rocket",
		"name": "航天模型",
		"size": [
			1,
			3
		],
		"quality": 4,
		"value": 2500,
		"tags": [
			"玩具",
			"收藏品"
		],
		"compact_premium": false
	},
	{
		"kind": "painting",
		"name": "海岸油画",
		"size": [
			4,
			3
		],
		"quality": 3,
		"value": 1800,
		"tags": [
			"艺术品",
			"收藏品"
		],
		"compact_premium": false
	},
	{
		"kind": "sculpture",
		"name": "青铜雕塑",
		"size": [
			2,
			3
		],
		"quality": 4,
		"value": 3100,
		"tags": [
			"艺术品",
			"古董"
		],
		"compact_premium": false
	},
	{
		"kind": "tea_set",
		"name": "彩绘茶具",
		"size": [
			3,
			2
		],
		"quality": 2,
		"value": 1200,
		"tags": [
			"艺术品",
			"收藏品"
		],
		"compact_premium": false
	},
	{
		"kind": "stamps",
		"name": "纪念邮票册",
		"size": [
			2,
			2
		],
		"quality": 1,
		"value": 500,
		"tags": [
			"收藏品",
			"古董"
		],
		"compact_premium": false
	},
	{
		"kind": "globe",
		"name": "黄铜地球仪",
		"size": [
			3,
			3
		],
		"quality": 3,
		"value": 1500,
		"tags": [
			"收藏品",
			"精密器械"
		],
		"compact_premium": false
	},
	{
		"kind": "usb_drive",
		"name": "金属U盘",
		"size": [
			1,
			1
		],
		"quality": 1,
		"value": 650,
		"tags": [
			"电子产品",
			"收藏品"
		],
		"compact_premium": false
	},
	{
		"kind": "flashlight",
		"name": "战术手电",
		"size": [
			1,
			2
		],
		"quality": 1,
		"value": 550,
		"tags": [
			"户外装备",
			"工具"
		],
		"compact_premium": false
	},
	{
		"kind": "battery",
		"name": "锂电池",
		"size": [
			1,
			1
		],
		"quality": 0,
		"value": 180,
		"tags": [
			"电子产品"
		],
		"compact_premium": false
	},
	{
		"kind": "ssd",
		"name": "高速固态盘",
		"size": [
			1,
			1
		],
		"quality": 2,
		"value": 1350,
		"tags": [
			"电子产品",
			"精密器械"
		],
		"compact_premium": false
	},
	{
		"kind": "cpu",
		"name": "旗舰处理器",
		"size": [
			1,
			1
		],
		"quality": 4,
		"value": 4500,
		"tags": [
			"电子产品",
			"精密器械"
		],
		"compact_premium": true
	},
	{
		"kind": "secure_chip",
		"name": "量子加密芯片",
		"size": [
			1,
			1
		],
		"quality": 6,
		"value": 40000,
		"tags": [
			"电子产品",
			"精密器械"
		],
		"compact_premium": true
	},
	{
		"kind": "classified_drive",
		"name": "绝密数据核心",
		"size": [
			1,
			2
		],
		"quality": 6,
		"value": 48000,
		"tags": [
			"电子产品",
			"收藏品"
		],
		"compact_premium": true
	},
	{
		"kind": "pink_diamond",
		"name": "绯色永恒",
		"size": [
			1,
			1
		],
		"quality": 6,
		"value": 52000,
		"tags": [
			"珠宝",
			"收藏品"
		],
		"compact_premium": true
	},
	{
		"kind": "blue_diamond",
		"name": "深海之瞳",
		"size": [
			1,
			1
		],
		"quality": 6,
		"value": 56000,
		"tags": [
			"珠宝",
			"艺术品"
		],
		"compact_premium": true
	},
	{
		"kind": "ruby",
		"name": "鸽血红宝石",
		"size": [
			1,
			1
		],
		"quality": 5,
		"value": 18000,
		"tags": [
			"珠宝",
			"收藏品"
		],
		"compact_premium": true
	},
	{
		"kind": "emerald",
		"name": "祖母绿之星",
		"size": [
			1,
			1
		],
		"quality": 5,
		"value": 16500,
		"tags": [
			"珠宝",
			"艺术品"
		],
		"compact_premium": true
	},
	{
		"kind": "jade_pendant",
		"name": "羊脂玉佩",
		"size": [
			1,
			1
		],
		"quality": 4,
		"value": 4600,
		"tags": [
			"珠宝",
			"古董"
		],
		"compact_premium": true
	},
	{
		"kind": "pocket_watch",
		"name": "珐琅金怀表",
		"size": [
			1,
			1
		],
		"quality": 5,
		"value": 14000,
		"tags": [
			"古董",
			"精密器械"
		],
		"compact_premium": true
	},
	{
		"kind": "ancient_coin",
		"name": "古代金币",
		"size": [
			1,
			1
		],
		"quality": 3,
		"value": 2200,
		"tags": [
			"古董",
			"收藏品"
		],
		"compact_premium": false
	},
	{
		"kind": "stamp_single",
		"name": "珍邮孤品",
		"size": [
			1,
			1
		],
		"quality": 4,
		"value": 3800,
		"tags": [
			"收藏品",
			"艺术品"
		],
		"compact_premium": true
	},
	{
		"kind": "data_tape",
		"name": "科研数据磁带",
		"size": [
			1,
			1
		],
		"quality": 5,
		"value": 15000,
		"tags": [
			"电子产品",
			"收藏品"
		],
		"compact_premium": true
	},
	{
		"kind": "camera_lens",
		"name": "定焦镜头",
		"size": [
			1,
			2
		],
		"quality": 3,
		"value": 2400,
		"tags": [
			"电子产品",
			"精密器械"
		],
		"compact_premium": false
	},
	{
		"kind": "walkie_talkie",
		"name": "便携对讲机",
		"size": [
			1,
			2
		],
		"quality": 1,
		"value": 900,
		"tags": [
			"电子产品",
			"户外装备"
		],
		"compact_premium": false
	},
	{
		"kind": "multitool",
		"name": "折叠多用钳",
		"size": [
			1,
			1
		],
		"quality": 1,
		"value": 650,
		"tags": [
			"工具",
			"户外装备"
		],
		"compact_premium": false
	},
	{
		"kind": "perfume",
		"name": "水晶香水瓶",
		"size": [
			1,
			1
		],
		"quality": 2,
		"value": 1400,
		"tags": [
			"收藏品",
			"艺术品"
		],
		"compact_premium": false
	},
	{
		"kind": "silver_coin",
		"name": "纪念银币",
		"size": [
			1,
			1
		],
		"quality": 1,
		"value": 750,
		"tags": [
			"珠宝",
			"收藏品"
		],
		"compact_premium": false
	},
	{
		"kind": "floppy_disk",
		"name": "旧式软盘",
		"size": [
			1,
			1
		],
		"quality": 0,
		"value": 250,
		"tags": [
			"电子产品",
			"古董"
		],
		"compact_premium": false
	},
	{
		"kind": "playing_cards",
		"name": "旧扑克牌",
		"size": [
			1,
			1
		],
		"quality": 0,
		"value": 200,
		"tags": [
			"玩具",
			"收藏品"
		],
		"compact_premium": false
	},
	{
		"kind": "matchbox",
		"name": "防潮火柴",
		"size": [
			1,
			1
		],
		"quality": 0,
		"value": 100,
		"tags": [
			"户外装备",
			"工具"
		],
		"compact_premium": false
	},
	{
		"kind": "piano",
		"name": "音乐会三角钢琴",
		"size": [
			8,
			7
		],
		"quality": 6,
		"value": 30000,
		"tags": [
			"音乐",
			"艺术品"
		],
		"compact_premium": false
	},
	{
		"kind": "arcade_cabinet",
		"name": "复古街机柜",
		"size": [
			4,
			6
		],
		"quality": 5,
		"value": 11000,
		"tags": [
			"电子产品",
			"玩具"
		],
		"compact_premium": false
	},
	{
		"kind": "fridge",
		"name": "双门冰箱",
		"size": [
			4,
			7
		],
		"quality": 3,
		"value": 4500,
		"tags": [
			"电子产品",
			"工具"
		],
		"compact_premium": false
	},
	{
		"kind": "motorcycle",
		"name": "经典巡航摩托",
		"size": [
			7,
			4
		],
		"quality": 5,
		"value": 12500,
		"tags": [
			"户外装备",
			"收藏品"
		],
		"compact_premium": false
	},
	{
		"kind": "telescope",
		"name": "天文观测镜",
		"size": [
			3,
			6
		],
		"quality": 4,
		"value": 4800,
		"tags": [
			"精密器械",
			"户外装备"
		],
		"compact_premium": false
	},
	{
		"kind": "gramophone",
		"name": "古董留声机",
		"size": [
			3,
			4
		],
		"quality": 4,
		"value": 4000,
		"tags": [
			"音乐",
			"古董"
		],
		"compact_premium": false
	},
	{
		"kind": "diving_helmet",
		"name": "古董潜水头盔",
		"size": [
			3,
			3
		],
		"quality": 5,
		"value": 10500,
		"tags": [
			"古董",
			"户外装备"
		],
		"compact_premium": false
	},
	{
		"kind": "safe",
		"name": "机械保险柜",
		"size": [
			4,
			4
		],
		"quality": 4,
		"value": 5500,
		"tags": [
			"工具",
			"收藏品"
		],
		"compact_premium": false
	},
	{
		"kind": "jukebox",
		"name": "鎏金点唱机",
		"size": [
			4,
			6
		],
		"quality": 6,
		"value": 34000,
		"tags": [
			"音乐",
			"电子产品"
		],
		"compact_premium": false
	},
	{
		"kind": "server_rack",
		"name": "数据服务器机柜",
		"size": [
			4,
			8
		],
		"quality": 5,
		"value": 13000,
		"tags": [
			"电子产品",
			"精密器械"
		],
		"compact_premium": false
	},
	{
		"kind": "vintage_car",
		"name": "典藏古董跑车",
		"size": [
			10,
			6
		],
		"quality": 6,
		"value": 36000,
		"tags": [
			"古董",
			"收藏品"
		],
		"compact_premium": false
	},
	{
		"kind": "robot_arm",
		"name": "精密工业机械臂",
		"size": [
			5,
			5
		],
		"quality": 5,
		"value": 12000,
		"tags": [
			"电子产品",
			"工具"
		],
		"compact_premium": false
	},
	{
		"kind": "fossil_skeleton",
		"name": "史前化石骨架",
		"size": [
			9,
			5
		],
		"quality": 6,
		"value": 32000,
		"tags": [
			"收藏品",
			"艺术品"
		],
		"compact_premium": false
	},
	{
		"kind": "harp",
		"name": "宫廷音乐竖琴",
		"size": [
			4,
			7
		],
		"quality": 5,
		"value": 10000,
		"tags": [
			"音乐",
			"艺术品"
		],
		"compact_premium": false
	},
	{
		"kind": "printing_press",
		"name": "古董印刷机",
		"size": [
			6,
			5
		],
		"quality": 5,
		"value": 11500,
		"tags": [
			"工具",
			"古董"
		],
		"compact_premium": false
	},
	{
		"kind": "grandfather_clock",
		"name": "雕花落地钟",
		"size": [
			3,
			8
		],
		"quality": 4,
		"value": 5200,
		"tags": [
			"古董",
			"精密器械"
		],
		"compact_premium": false
	},
	{
		"kind": "rusty_nails",
		"name": "生锈钉子盒",
		"size": [
			1,
			1
		],
		"quality": 0,
		"value": 40,
		"tags": [
			"工具"
		],
		"compact_premium": false
	},
	{
		"kind": "tape_roll",
		"name": "布基胶带",
		"size": [
			1,
			1
		],
		"quality": 0,
		"value": 60,
		"tags": [
			"工具"
		],
		"compact_premium": false
	},
	{
		"kind": "soap",
		"name": "洗衣皂",
		"size": [
			1,
			1
		],
		"quality": 0,
		"value": 35,
		"tags": [
			"户外装备"
		],
		"compact_premium": false
	},
	{
		"kind": "work_gloves",
		"name": "劳保手套",
		"size": [
			1,
			1
		],
		"quality": 0,
		"value": 90,
		"tags": [
			"工具",
			"户外装备"
		],
		"compact_premium": false
	},
	{
		"kind": "screwdriver",
		"name": "平口螺丝刀",
		"size": [
			1,
			2
		],
		"quality": 0,
		"value": 110,
		"tags": [
			"工具"
		],
		"compact_premium": false
	},
	{
		"kind": "ceramic_mug",
		"name": "搪瓷水杯",
		"size": [
			1,
			1
		],
		"quality": 0,
		"value": 80,
		"tags": [
			"户外装备"
		],
		"compact_premium": false
	},
	{
		"kind": "cloth_rag",
		"name": "旧抹布",
		"size": [
			1,
			1
		],
		"quality": 0,
		"value": 30,
		"tags": [
			"工具"
		],
		"compact_premium": false
	},
	{
		"kind": "plastic_bottle",
		"name": "塑料水壶",
		"size": [
			1,
			2
		],
		"quality": 0,
		"value": 70,
		"tags": [
			"户外装备"
		],
		"compact_premium": false
	},
	{
		"kind": "padlock",
		"name": "黄铜挂锁",
		"size": [
			1,
			1
		],
		"quality": 1,
		"value": 150,
		"tags": [
			"工具",
			"精密器械"
		],
		"compact_premium": false
	},
	{
		"kind": "measuring_tape",
		"name": "钢卷尺",
		"size": [
			1,
			1
		],
		"quality": 1,
		"value": 180,
		"tags": [
			"工具",
			"精密器械"
		],
		"compact_premium": false
	},
	{
		"kind": "copper_wire",
		"name": "铜线卷",
		"size": [
			2,
			1
		],
		"quality": 1,
		"value": 240,
		"tags": [
			"电子产品",
			"工具"
		],
		"compact_premium": false
	},
	{
		"kind": "charger",
		"name": "手机充电头",
		"size": [
			1,
			1
		],
		"quality": 1,
		"value": 170,
		"tags": [
			"电子产品"
		],
		"compact_premium": false
	},
	{
		"kind": "keyboard",
		"name": "旧式键盘",
		"size": [
			3,
			1
		],
		"quality": 1,
		"value": 260,
		"tags": [
			"电子产品"
		],
		"compact_premium": false
	},
	{
		"kind": "calculator",
		"name": "袖珍计算器",
		"size": [
			1,
			1
		],
		"quality": 1,
		"value": 220,
		"tags": [
			"电子产品",
			"工具"
		],
		"compact_premium": false
	},
	{
		"kind": "harmonica",
		"name": "十孔口琴",
		"size": [
			1,
			1
		],
		"quality": 1,
		"value": 200,
		"tags": [
			"音乐",
			"收藏品"
		],
		"compact_premium": false
	},
	{
		"kind": "toy_car",
		"name": "玩具小汽车",
		"size": [
			1,
			1
		],
		"quality": 1,
		"value": 160,
		"tags": [
			"玩具",
			"收藏品"
		],
		"compact_premium": false
	},
	{
		"kind": "memory_card",
		"name": "高速存储卡",
		"size": [
			1,
			1
		],
		"quality": 2,
		"value": 320,
		"tags": [
			"电子产品",
			"精密器械"
		],
		"compact_premium": false
	},
	{
		"kind": "digital_thermometer",
		"name": "电子温度计",
		"size": [
			1,
			2
		],
		"quality": 2,
		"value": 380,
		"tags": [
			"电子产品",
			"精密器械"
		],
		"compact_premium": false
	},
	{
		"kind": "portable_scale",
		"name": "便携电子秤",
		"size": [
			1,
			2
		],
		"quality": 2,
		"value": 450,
		"tags": [
			"电子产品",
			"工具"
		],
		"compact_premium": false
	},
	{
		"kind": "soldering_iron",
		"name": "恒温电烙铁",
		"size": [
			1,
			3
		],
		"quality": 2,
		"value": 600,
		"tags": [
			"电子产品",
			"工具"
		],
		"compact_premium": false
	}
]

## Inputs are catalogue/lot records. Never mutates inputs or compounds a previous appraisal.
static func evaluate(lot: Array) -> Dictionary:
	var counts: Dictionary = {}
	for item: Dictionary in lot:
		var seen: Array = []
		for tag: String in item.tags:
			if not seen.has(tag):
				counts[tag] = int(counts.get(tag, 0)) + 1
				seen.append(tag)
	var groups: Array[Dictionary] = []
	var rates: Dictionary = {}
	for tag: String in TAGS:
		var count: int = int(counts.get(tag, 0))
		if count == 0:
			continue
		var percent: int = 30 if count >= 5 else (15 if count >= 3 else 0)
		rates[tag] = percent
		groups.append({"tag": tag, "count": count, "percent": percent})
	var records: Array[Dictionary] = []
	var base_value: int = 0
	var bonus_value: int = 0
	for item: Dictionary in lot:
		var record: Dictionary = item.duplicate(true)
		var percent: int = 0
		var seen: Array = []
		for tag: String in record.tags:
			if not seen.has(tag):
				percent += int(rates.get(tag, 0))
				seen.append(tag)
		percent = mini(percent, 60)
		# Integer floor per item is the sole rounding rule.
		var bonus: int = int(int(record.value) * percent / 100.0)
		record["bonus_percent"] = percent
		record["bonus_value"] = bonus
		record["effective_value"] = int(record.value) + bonus
		base_value += int(record.value)
		bonus_value += bonus
		records.append(record)
	return {"items": records, "tags": groups, "base_value": base_value, "bonus_value": bonus_value, "total_value": base_value + bonus_value}


## Pack largest footprints first with stable index ties; returned rectangles preserve item order.
## Host rejects an unplaceable lot before publication. Renderer uses this exact same layout.
static func pack(lot: Array) -> Array[Rect2i]:
	var order: Array[int] = []
	var result: Array[Rect2i] = []
	var occupied: Array[bool] = []
	occupied.resize(GRID_COLUMNS * GRID_ROWS)
	occupied.fill(false)
	for index: int in lot.size():
		order.append(index)
		result.append(Rect2i())
	order.sort_custom(func(a: int, b: int) -> bool:
		var area_a: int = int(lot[a].size[0]) * int(lot[a].size[1])
		var area_b: int = int(lot[b].size[0]) * int(lot[b].size[1])
		return a < b if area_a == area_b else area_a > area_b)
	for index: int in order:
		var footprint: Vector2i = Vector2i(int(lot[index].size[0]), int(lot[index].size[1]))
		if footprint.x < 1 or footprint.y < 1 or footprint.x > GRID_COLUMNS or footprint.y > GRID_ROWS:
			return []
		var placed: bool = false
		for row: int in range(GRID_ROWS - footprint.y + 1):
			for column: int in range(GRID_COLUMNS - footprint.x + 1):
				var candidate: Rect2i = Rect2i(Vector2i(column, row), footprint)
				var fits: bool = true
				for y: int in range(candidate.position.y, candidate.end.y):
					for x: int in range(candidate.position.x, candidate.end.x):
						if occupied[y * GRID_COLUMNS + x]:
							fits = false
				if not fits:
					continue
				result[index] = candidate
				for y: int in range(candidate.position.y, candidate.end.y):
					for x: int in range(candidate.position.x, candidate.end.x):
						occupied[y * GRID_COLUMNS + x] = true
				placed = true
				break
			if placed:
				break
		if not placed:
			return []
	return result


