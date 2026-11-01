## Business-owned setting defaults, constraints and UI hierarchy. No runtime side effects.
extends RefCounted

static func schema() -> Dictionary:
	return {
		"schema_format": 3,
		"settings_version": 1,
		"fields": {
			"warehouses": {
				"type": "int",
				"default": 3,
				"title": "仓库数量",
				"audience": "room",
				"apply": "next_round",
				"min": 1,
				"max": 10,
				"control": "number"
			},
			"round_seconds": {
				"type": "int",
				"default": 15,
				"title": "每轮竞价秒数",
				"audience": "room",
				"apply": "next_round",
				"min": 5,
				"max": 60,
				"control": "number"
			},
			"coins": {
				"type": "int",
				"default": 10000,
				"title": "初始金币",
				"audience": "room",
				"apply": "next_round",
				"min": 1000,
				"max": 100000,
				"control": "number"
			}
		},
		"layout": [
			{
				"id": "room",
				"title": "游戏规则",
				"expanded": true,
				"children": [
					{
						"field": "warehouses"
					},
					{
						"field": "round_seconds"
					},
					{
						"field": "coins"
					}
				]
			}
		]
	}
