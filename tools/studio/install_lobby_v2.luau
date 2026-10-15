-- Edit-only. Uses measured Blender bounds; preserves full lobby and raw import backups.
-- Refuses to run twice. No Rojo scripts, lighting, paths, arenas or UI templates are changed.
assert(not game:GetService("RunService"):IsRunning(), "Edit mode required")
local Data = game:GetService("HttpService"):JSONDecode([==[{"Kiln_Furnace":{"Position":[-22,0.05,-11],"Yaw":0,"Meshes":[{"Name":"Kiln_Base","Center":[0,-0.3000001907348633,0.32499998807907104],"Size":[11.800000190734863,9.399999618530273,0.6499999761581421],"Color":"C8BC9C","Material":"SmoothPlastic"},{"Name":"Kiln_Hearth","Center":[0,0.6999999284744263,0.9749999940395355],"Size":[9.399999618530273,6.799999952316284,0.6499999165534973],"Color":"BA7052","Material":"SmoothPlastic"},{"Name":"Kiln_Side_-3_65","Center":[-3.6500000953674316,1.1499999165534973,3.6500000953674316],"Size":[2.0500001907348633,5.099999785423279,4.949999809265137],"Color":"C8BC9C","Material":"SmoothPlastic"},{"Name":"Kiln_CornerBand_-3_65","Center":[-4.526000022888184,1.1500000357627869,3.200000047683716],"Size":[0.3000001907348633,5.2500001192092896,0.4200000762939453],"Color":"B87E50","Material":"SmoothPlastic"},{"Name":"Kiln_Side_3_65","Center":[3.6500000953674316,1.1499999165534973,3.6500000953674316],"Size":[2.0500001907348633,5.099999785423279,4.949999809265137],"Color":"C8BC9C","Material":"SmoothPlastic"},{"Name":"Kiln_CornerBand_3_65","Center":[4.526000022888184,1.1500000357627869,3.200000047683716],"Size":[0.3000001907348633,5.2500001192092896,0.4200000762939453],"Color":"B87E50","Material":"SmoothPlastic"},{"Name":"Kiln_Back","Center":[0,3.549999952316284,3.900000214576721],"Size":[7.5,0.6999998092651367,5.400000333786011],"Color":"C8BC9C","Material":"SmoothPlastic"},{"Name":"Kiln_Jamb_-2_75_0","Center":[-2.75,-1.7200000286102295,1.7499999403953552],"Size":[1.1500000953674316,1.0999999046325684,0.9499999284744263],"Color":"BA7052","Material":"SmoothPlastic"},{"Name":"Kiln_Jamb_-2_75_1","Center":[-2.75,-1.7200000286102295,2.7100000381469727],"Size":[1.1500000953674316,1.0999999046325684,0.9499998092651367],"Color":"BA7052","Material":"SmoothPlastic"},{"Name":"Kiln_Jamb_-2_75_2","Center":[-2.75,-1.7200000286102295,3.6700000762939453],"Size":[1.1500000953674316,1.0999999046325684,0.9499998092651367],"Color":"BA7052","Material":"SmoothPlastic"},{"Name":"Kiln_Jamb_2_75_0","Center":[2.75,-1.7200000286102295,1.7499999403953552],"Size":[1.1500000953674316,1.0999999046325684,0.9499999284744263],"Color":"BA7052","Material":"SmoothPlastic"},{"Name":"Kiln_Jamb_2_75_1","Center":[2.75,-1.7200000286102295,2.7100000381469727],"Size":[1.1500000953674316,1.0999999046325684,0.9499998092651367],"Color":"BA7052","Material":"SmoothPlastic"},{"Name":"Kiln_Jamb_2_75_2","Center":[2.75,-1.7200000286102295,3.6700000762939453],"Size":[1.1500000953674316,1.0999999046325684,0.9499998092651367],"Color":"BA7052","Material":"SmoothPlastic"},{"Name":"Kiln_Arch_00","Center":[2.697161078453064,-1.7199999690055847,4.617321252822876],"Size":[1.2854640483856201,1.1200000047683716,1.0997624397277832],"Color":"BA7052","Material":"SmoothPlastic"},{"Name":"Kiln_Arch_01","Center":[2.405233860015869,-1.7199999690055847,5.494170904159546],"Size":[1.4482007026672363,1.1200000047683716,1.3644051551818848],"Color":"BA7052","Material":"SmoothPlastic"},{"Name":"Kiln_Arch_02","Center":[1.823199987411499,-1.7199999690055847,6.196832180023193],"Size":[1.436263084411621,1.1200000047683716,1.4644804000854492],"Color":"BA7052","Material":"SmoothPlastic"},{"Name":"Kiln_Arch_03","Center":[1.0212611854076385,-1.7199999690055847,6.640553712844849],"Size":[1.2510908246040344,1.1200000047683716,1.3879179954528809],"Color":"BA7052","Material":"SmoothPlastic"},{"Name":"Kiln_Arch_04","Center":[0,-1.7199999690055847,6.7718164920806885],"Size":[1.1073051691055298,1.1200000047683716,1.1439518928527832],"Color":"BA7052","Material":"SmoothPlastic"},{"Name":"Kiln_Arch_05","Center":[-1.0212611854076385,-1.7199999690055847,6.640553712844849],"Size":[1.2510908246040344,1.1200000047683716,1.3879179954528809],"Color":"BA7052","Material":"SmoothPlastic"},{"Name":"Kiln_Arch_06","Center":[-1.823199987411499,-1.7199999690055847,6.196832180023193],"Size":[1.436263084411621,1.1200000047683716,1.4644804000854492],"Color":"BA7052","Material":"SmoothPlastic"},{"Name":"Kiln_Arch_07","Center":[-2.405233860015869,-1.7199999690055847,5.494170904159546],"Size":[1.4482007026672363,1.1200000047683716,1.3644051551818848],"Color":"BA7052","Material":"SmoothPlastic"},{"Name":"Kiln_Arch_08","Center":[-2.697161078453064,-1.7199999690055847,4.617321252822876],"Size":[1.2854640483856201,1.1200000047683716,1.0997624397277832],"Color":"BA7052","Material":"SmoothPlastic"},{"Name":"Kiln_ChamberDark","Center":[0,0.699999988079071,3.199999988079071],"Size":[4.300000190734863,0.2200000286102295,3.7999998331069946],"Color":"654D46","Material":"SmoothPlastic"},{"Name":"Kiln_MoltenPool","Center":[0,-0.20000004768371582,1.4299999475479126],"Size":[3.1600000858306885,3.1600000858306885,0.15000009536743164],"Color":"FFB958","Material":"Neon"},{"Name":"Kiln_ChamberBackGlow","Center":[0,0.5199999809265137,2.900000035762787],"Size":[3.200000047683716,0.12000000476837158,2.1999999284744263],"Color":"FFB958","Material":"Neon"},{"Name":"Kiln_Roof","Center":[0,1.0499999523162842,7.624999761581421],"Size":[9.399999618530273,9.400000095367432,2.049999713897705],"Color":"C8BC9C","Material":"SmoothPlastic"},{"Name":"Kiln_RoofBand","Center":[0,1.0499999523162842,6.869999885559082],"Size":[9.4399995803833,9.440000057220459,0.3000001907348633],"Color":"B87E50","Material":"SmoothPlastic"},{"Name":"Kiln_Chimney","Center":[0.7999999821186066,2.049999952316284,10.100000381469727],"Size":[2.0999998450279236,2.0999999046325684,3.3500003814697266],"Color":"BA7052","Material":"SmoothPlastic"},{"Name":"Kiln_ChimneyRim","Center":[0.7999999821186066,2.049999952316284,11.920000076293945],"Size":[2.5599998831748962,2.559999942779541,0.37999916076660156],"Color":"B87E50","Material":"SmoothPlastic"},{"Name":"Kiln_ChimneyDark","Center":[0.8000000417232513,2.0499998927116394,12.130000114440918],"Size":[1.7600000500679016,1.7599998712539673,0.07999992370605469],"Color":"654D46","Material":"SmoothPlastic"},{"Name":"Kiln_CoolingTray","Center":[0,-3.349999785423279,1.7000000476837158],"Size":[4.900000095367432,3.5999996662139893,0.4200000762939453],"Color":"B87E50","Material":"SmoothPlastic"},{"Name":"Kiln_CoolingSurface","Center":[0,-3.450000047683716,1.9699999690055847],"Size":[4.300000190734863,3.1500000953674316,0.15999996662139893],"Color":"26374B","Material":"SmoothPlastic"},{"Name":"Kiln_TrayLip_-2_28","Center":[-2.2799999713897705,-3.3499999046325684,2.049999952316284],"Size":[0.2199997901916504,3.5,0.38000011444091797],"Color":"B87E50","Material":"SmoothPlastic"},{"Name":"Kiln_TrayLeg_-2_28","Center":[-2.2799999713897705,-4.400000095367432,0.9499999582767487],"Size":[0.4499998092651367,0.5500001907348633,1.449999988079071],"Color":"26374B","Material":"SmoothPlastic"},{"Name":"Kiln_TrayLip_2_28","Center":[2.2799999713897705,-3.3499999046325684,2.049999952316284],"Size":[0.2199997901916504,3.5,0.38000011444091797],"Color":"B87E50","Material":"SmoothPlastic"},{"Name":"Kiln_TrayLeg_2_28","Center":[2.2799999713897705,-4.400000095367432,0.9499999582767487],"Size":[0.4499998092651367,0.5500001907348633,1.449999988079071],"Color":"26374B","Material":"SmoothPlastic"},{"Name":"Kiln_RevealSeat","Center":[0,-4.019999980926514,2.119999885559082],"Size":[2.259999990463257,2.260000228881836,0.17999982833862305],"Color":"70B4BC","Material":"SmoothPlastic"},{"Name":"Kiln_RevealSeatInset","Center":[0,-4.019999980926514,2.240000009536743],"Size":[1.7999999523162842,1.8000001907348633,0.059999942779541016],"Color":"26374B","Material":"SmoothPlastic"},{"Name":"Kiln_DisplayPost","Center":[5.400000095367432,-2.25,1.9999999403953552],"Size":[0.4200000762939453,0.6500000953674316,3.1999999284744263],"Color":"26374B","Material":"SmoothPlastic"},{"Name":"Kiln_DisplayFrame","Center":[5.25,-2.2499999403953552,4.25],"Size":[2.3999996185302734,0.6999999284744263,2.6999998092651367],"Color":"B87E50","Material":"SmoothPlastic"},{"Name":"Kiln_DisplaySurface","Center":[5.25,-2.6600000858306885,4.25],"Size":[2.0500001907348633,0.11999988555908203,2.3299999237060547],"Color":"26374B","Material":"SmoothPlastic"},{"Name":"Kiln_HeaderPlaque","Center":[0,-3.75,7.8999998569488525],"Size":[4.400000095367432,0.34999990463256836,0.8499999046325684],"Color":"26374B","Material":"SmoothPlastic"}]},"Board_MatchWins":{"Position":[-14,0.05,21],"Yaw":180,"Meshes":[{"Name":"Board_MatchWins_Foot","Center":[0,0,0.30000001192092896],"Size":[12.199999809265137,3.200000047683716,0.6000000238418579],"Color":"C8BC9C","Material":"SmoothPlastic"},{"Name":"Board_MatchWins_Step","Center":[0,-0.1499999761581421,0.7799999713897705],"Size":[11.300000190734863,2.5999999046325684,0.36000001430511475],"Color":"B87E50","Material":"SmoothPlastic"},{"Name":"Board_MatchWins_Column_-5_65","Center":[-5.650000095367432,0,5.699999809265137],"Size":[0.8999996185302734,1.149999976158142,9.5],"Color":"C8BC9C","Material":"SmoothPlastic"},{"Name":"Board_MatchWins_ColumnCap_-5_65","Center":[-5.650000095367432,0,10.449999809265137],"Size":[1.1000003814697266,1.350000023841858,0.39999961853027344],"Color":"B87E50","Material":"SmoothPlastic"},{"Name":"Board_MatchWins_BaseCap_-5_65","Center":[-5.650000095367432,0,1.149999976158142],"Size":[1.1000003814697266,1.350000023841858,0.4500000476837158],"Color":"B87E50","Material":"SmoothPlastic"},{"Name":"Board_MatchWins_Column_5_65","Center":[5.650000095367432,0,5.699999809265137],"Size":[0.8999996185302734,1.149999976158142,9.5],"Color":"C8BC9C","Material":"SmoothPlastic"},{"Name":"Board_MatchWins_ColumnCap_5_65","Center":[5.650000095367432,0,10.449999809265137],"Size":[1.1000003814697266,1.350000023841858,0.39999961853027344],"Color":"B87E50","Material":"SmoothPlastic"},{"Name":"Board_MatchWins_BaseCap_5_65","Center":[5.650000095367432,0,1.149999976158142],"Size":[1.1000003814697266,1.350000023841858,0.4500000476837158],"Color":"B87E50","Material":"SmoothPlastic"},{"Name":"Board_MatchWins_Display","Center":[0,-0.1599999964237213,6.150000095367432],"Size":[10.199999809265137,0.3799999952316284,7.800000190734863],"Color":"26374B","Material":"SmoothPlastic"},{"Name":"Board_MatchWins_Crossbar_2_08","Center":[0,0,2.07999986410141],"Size":[12.100000381469727,1.0499999523162842,0.44999992847442627],"Color":"B87E50","Material":"SmoothPlastic"},{"Name":"Board_MatchWins_Crossbar_10_22","Center":[0,0,10.220000267028809],"Size":[12.100000381469727,1.0499999523162842,0.4500007629394531],"Color":"B87E50","Material":"SmoothPlastic"},{"Name":"Board_MatchWins_Header","Center":[0,-0.18000001460313797,10.949999809265137],"Size":[10.100000381469727,0.48000000417232513,1.0499992370605469],"Color":"C8BC9C","Material":"SmoothPlastic"},{"Name":"Board_MatchWins_HeaderInset","Center":[0,-0.47999997437000275,10.949999809265137],"Size":[9.600000381469727,0.1199999749660492,0.7199993133544922],"Color":"26374B","Material":"SmoothPlastic"},{"Name":"Board_MatchWins_CrestFoot","Center":[0,0,11.649999618530273],"Size":[2.299999952316284,1.2000000476837158,0.3600006103515625],"Color":"B87E50","Material":"SmoothPlastic"},{"Name":"Board_MatchWins_CrownPoint_-0_6","Center":[-0.5999999940395355,0,12.050000190734863],"Size":[0.85999995470047,0.8600000143051147,0.8999996185302734],"Color":"70B4BC","Material":"SmoothPlastic"},{"Name":"Board_MatchWins_CrownPoint_0","Center":[0,0,12.5],"Size":[0.8600000143051147,0.8600000143051147,0.8999996185302734],"Color":"70B4BC","Material":"SmoothPlastic"},{"Name":"Board_MatchWins_CrownPoint_0_6","Center":[0.5999999940395355,0,12.050000190734863],"Size":[0.85999995470047,0.8600000143051147,0.8999996185302734],"Color":"70B4BC","Material":"SmoothPlastic"}]},"Board_Shatters":{"Position":[14,0.05,21],"Yaw":180,"Meshes":[{"Name":"Board_Shatters_Foot","Center":[0,0,0.30000001192092896],"Size":[12.199999809265137,3.200000047683716,0.6000000238418579],"Color":"C8BC9C","Material":"SmoothPlastic"},{"Name":"Board_Shatters_Step","Center":[0,-0.1499999761581421,0.7799999713897705],"Size":[11.300000190734863,2.5999999046325684,0.36000001430511475],"Color":"B87E50","Material":"SmoothPlastic"},{"Name":"Board_Shatters_Column_-5_65","Center":[-5.650000095367432,0,5.699999809265137],"Size":[0.8999996185302734,1.149999976158142,9.5],"Color":"C8BC9C","Material":"SmoothPlastic"},{"Name":"Board_Shatters_ColumnCap_-5_65","Center":[-5.650000095367432,0,10.449999809265137],"Size":[1.1000003814697266,1.350000023841858,0.39999961853027344],"Color":"B87E50","Material":"SmoothPlastic"},{"Name":"Board_Shatters_BaseCap_-5_65","Center":[-5.650000095367432,0,1.149999976158142],"Size":[1.1000003814697266,1.350000023841858,0.4500000476837158],"Color":"B87E50","Material":"SmoothPlastic"},{"Name":"Board_Shatters_Column_5_65","Center":[5.650000095367432,0,5.699999809265137],"Size":[0.8999996185302734,1.149999976158142,9.5],"Color":"C8BC9C","Material":"SmoothPlastic"},{"Name":"Board_Shatters_ColumnCap_5_65","Center":[5.650000095367432,0,10.449999809265137],"Size":[1.1000003814697266,1.350000023841858,0.39999961853027344],"Color":"B87E50","Material":"SmoothPlastic"},{"Name":"Board_Shatters_BaseCap_5_65","Center":[5.650000095367432,0,1.149999976158142],"Size":[1.1000003814697266,1.350000023841858,0.4500000476837158],"Color":"B87E50","Material":"SmoothPlastic"},{"Name":"Board_Shatters_Display","Center":[0,-0.1599999964237213,6.150000095367432],"Size":[10.199999809265137,0.3799999952316284,7.800000190734863],"Color":"26374B","Material":"SmoothPlastic"},{"Name":"Board_Shatters_Crossbar_2_08","Center":[0,0,2.07999986410141],"Size":[12.100000381469727,1.0499999523162842,0.44999992847442627],"Color":"B87E50","Material":"SmoothPlastic"},{"Name":"Board_Shatters_Crossbar_10_22","Center":[0,0,10.220000267028809],"Size":[12.100000381469727,1.0499999523162842,0.4500007629394531],"Color":"B87E50","Material":"SmoothPlastic"},{"Name":"Board_Shatters_Header","Center":[0,-0.18000001460313797,10.949999809265137],"Size":[10.100000381469727,0.48000000417232513,1.0499992370605469],"Color":"C8BC9C","Material":"SmoothPlastic"},{"Name":"Board_Shatters_HeaderInset","Center":[0,-0.47999997437000275,10.949999809265137],"Size":[9.600000381469727,0.1199999749660492,0.7199993133544922],"Color":"26374B","Material":"SmoothPlastic"},{"Name":"Board_Shatters_CrestFoot","Center":[0,0,11.649999618530273],"Size":[2.299999952316284,1.2000000476837158,0.3600006103515625],"Color":"B87E50","Material":"SmoothPlastic"},{"Name":"Board_Shatters_Shard_-0_65","Center":[-0.6499999761581421,0,12.119999885559082],"Size":[0.7799999713897705,0.7799999713897705,1.25],"Color":"9F8DBF","Material":"SmoothPlastic"},{"Name":"Board_Shatters_Shard_0","Center":[0,0,12.5],"Size":[0.7799999713897705,0.7799999713897705,1.25],"Color":"9F8DBF","Material":"SmoothPlastic"},{"Name":"Board_Shatters_Shard_0_65","Center":[0.6499999761581421,0,12.100000381469727],"Size":[0.7799999713897705,0.7799999713897705,1.25],"Color":"9F8DBF","Material":"SmoothPlastic"}]},"Board_Trophies":{"Position":[28,0.05,21],"Yaw":180,"Meshes":[{"Name":"Board_Trophies_Foot","Center":[0,0,0.30000001192092896],"Size":[12.199999809265137,3.200000047683716,0.6000000238418579],"Color":"C8BC9C","Material":"SmoothPlastic"},{"Name":"Board_Trophies_Step","Center":[0,-0.1499999761581421,0.7799999713897705],"Size":[11.300000190734863,2.5999999046325684,0.36000001430511475],"Color":"B87E50","Material":"SmoothPlastic"},{"Name":"Board_Trophies_Column_-5_65","Center":[-5.650000095367432,0,5.699999809265137],"Size":[0.8999996185302734,1.149999976158142,9.5],"Color":"C8BC9C","Material":"SmoothPlastic"},{"Name":"Board_Trophies_ColumnCap_-5_65","Center":[-5.650000095367432,0,10.449999809265137],"Size":[1.1000003814697266,1.350000023841858,0.39999961853027344],"Color":"B87E50","Material":"SmoothPlastic"},{"Name":"Board_Trophies_BaseCap_-5_65","Center":[-5.650000095367432,0,1.149999976158142],"Size":[1.1000003814697266,1.350000023841858,0.4500000476837158],"Color":"B87E50","Material":"SmoothPlastic"},{"Name":"Board_Trophies_Column_5_65","Center":[5.650000095367432,0,5.699999809265137],"Size":[0.8999996185302734,1.149999976158142,9.5],"Color":"C8BC9C","Material":"SmoothPlastic"},{"Name":"Board_Trophies_ColumnCap_5_65","Center":[5.650000095367432,0,10.449999809265137],"Size":[1.1000003814697266,1.350000023841858,0.39999961853027344],"Color":"B87E50","Material":"SmoothPlastic"},{"Name":"Board_Trophies_BaseCap_5_65","Center":[5.650000095367432,0,1.149999976158142],"Size":[1.1000003814697266,1.350000023841858,0.4500000476837158],"Color":"B87E50","Material":"SmoothPlastic"},{"Name":"Board_Trophies_Display","Center":[0,-0.1599999964237213,6.150000095367432],"Size":[10.199999809265137,0.3799999952316284,7.800000190734863],"Color":"26374B","Material":"SmoothPlastic"},{"Name":"Board_Trophies_Crossbar_2_08","Center":[0,0,2.07999986410141],"Size":[12.100000381469727,1.0499999523162842,0.44999992847442627],"Color":"B87E50","Material":"SmoothPlastic"},{"Name":"Board_Trophies_Crossbar_10_22","Center":[0,0,10.220000267028809],"Size":[12.100000381469727,1.0499999523162842,0.4500007629394531],"Color":"B87E50","Material":"SmoothPlastic"},{"Name":"Board_Trophies_Header","Center":[0,-0.18000001460313797,10.949999809265137],"Size":[10.100000381469727,0.48000000417232513,1.0499992370605469],"Color":"C8BC9C","Material":"SmoothPlastic"},{"Name":"Board_Trophies_HeaderInset","Center":[0,-0.47999997437000275,10.949999809265137],"Size":[9.600000381469727,0.1199999749660492,0.7199993133544922],"Color":"26374B","Material":"SmoothPlastic"},{"Name":"Board_Trophies_CrestFoot","Center":[0,0,11.649999618530273],"Size":[2.299999952316284,1.2000000476837158,0.3600006103515625],"Color":"B87E50","Material":"SmoothPlastic"},{"Name":"Board_Trophies_Cup","Center":[0,0,12.359999656677246],"Size":[2,2,1.0499992370605469],"Color":"E3BF69","Material":"SmoothPlastic"},{"Name":"Board_Trophies_Stem","Center":[0,0,11.899999618530273],"Size":[0.5,0.5,0.39999961853027344],"Color":"B87E50","Material":"SmoothPlastic"}]},"Fence_Isle_Lobby":{"Position":[0,0,0],"Yaw":0,"Meshes":[{"Name":"Fence_Isle_Lobby_Rails","Center":[-0.0042724609375,-0.0005922317504882812,1.5000000596046448],"Size":[94.78626251220703,54.79881477355957,1.8000000715255737],"Color":"855439","Material":"SmoothPlastic"},{"Name":"Fence_Isle_Lobby_Posts","Center":[-0.04436492919921875,-0.010662078857421875,1.4149999618530273],"Size":[94.85305786132812,55.03657150268555,2.8299999237060547],"Color":"694537","Material":"SmoothPlastic"},{"Name":"Fence_Isle_Lobby_Caps","Center":[-0.04436492919921875,-0.010662078857421875,2.9149999618530273],"Size":[95.01305389404297,55.196571350097656,0.1700000762939453],"Color":"B98A5C","Material":"SmoothPlastic"}]},"Fence_Isle_Arena1":{"Position":[0,2,-55],"Yaw":0,"Meshes":[{"Name":"Fence_Isle_Arena1_Rails","Center":[0.000965118408203125,-0.00142669677734375,1.5000000596046448],"Size":[90.79610443115234,44.79609298706055,1.8000000715255737],"Color":"855439","Material":"SmoothPlastic"},{"Name":"Fence_Isle_Arena1_Posts","Center":[0.038112640380859375,0.013472557067871094,1.4149999618530273],"Size":[90.80780029296875,45.02634239196777,2.8299999237060547],"Color":"694537","Material":"SmoothPlastic"},{"Name":"Fence_Isle_Arena1_Caps","Center":[0.038112640380859375,0.013472557067871094,2.9149999618530273],"Size":[90.9677963256836,45.18634223937988,0.1700000762939453],"Color":"B98A5C","Material":"SmoothPlastic"}]},"Fence_Isle_Arena2":{"Position":[0,4,-105],"Yaw":0,"Meshes":[{"Name":"Fence_Isle_Arena2_Rails","Center":[0.0004673004150390625,0.0006418228149414062,1.5000000596046448],"Size":[90.79705429077148,44.798200607299805,1.8000000715255737],"Color":"855439","Material":"SmoothPlastic"},{"Name":"Fence_Isle_Arena2_Posts","Center":[0.016632080078125,-0.016785621643066406,1.4149999618530273],"Size":[90.91149139404297,45.02334785461426,2.8299999237060547],"Color":"694537","Material":"SmoothPlastic"},{"Name":"Fence_Isle_Arena2_Caps","Center":[0.016632080078125,-0.016785621643066406,2.9149999618530273],"Size":[91.07148742675781,45.18334770202637,0.1700000762939453],"Color":"B98A5C","Material":"SmoothPlastic"}]},"Fence_Isle_Arena3":{"Position":[0,6,-155],"Yaw":0,"Meshes":[{"Name":"Fence_Isle_Arena3_Rails","Center":[0.0001544952392578125,-0.00007343292236328125,1.5000000596046448],"Size":[90.79760360717773,44.799631118774414,1.8000000715255737],"Color":"855439","Material":"SmoothPlastic"},{"Name":"Fence_Isle_Arena3_Posts","Center":[0.0039234161376953125,-0.02255725860595703,1.4149999618530273],"Size":[90.95773696899414,45.014665603637695,2.8299999237060547],"Color":"694537","Material":"SmoothPlastic"},{"Name":"Fence_Isle_Arena3_Caps","Center":[0.0039234161376953125,-0.02255725860595703,2.9149999618530273],"Size":[91.11773300170898,45.174665451049805,0.1700000762939453],"Color":"B98A5C","Material":"SmoothPlastic"}]},"Fence_Isle_Featured":{"Position":[0,9,-206],"Yaw":0,"Meshes":[{"Name":"Fence_Isle_Featured_Rails","Center":[-0.000339508056640625,0.00006580352783203125,1.5000000596046448],"Size":[70.79801940917969,46.79983711242676,1.8000000715255737],"Color":"855439","Material":"SmoothPlastic"},{"Name":"Fence_Isle_Featured_Posts","Center":[-0.0439910888671875,0.00922393798828125,1.4149999618530273],"Size":[70.9556884765625,47.02719497680664,2.8299999237060547],"Color":"694537","Material":"SmoothPlastic"},{"Name":"Fence_Isle_Featured_Caps","Center":[-0.0439910888671875,0.00922393798828125,2.9149999618530273],"Size":[71.11568450927734,47.18719482421875,0.1700000762939453],"Color":"B98A5C","Material":"SmoothPlastic"}]},"Fence_Bridge1":{"Position":[0,1,-29.929136276245117],"Yaw":0,"Meshes":[{"Name":"Fence_Bridge1_Rails","Center":[0.0000073909759521484375,0.0007628202438354492,1.5000000447034836],"Size":[11.563185214996338,7.286534070968628,3.800000101327896],"Color":"855439","Material":"SmoothPlastic"},{"Name":"Fence_Bridge1_Posts","Center":[-2.384185791015625e-7,-4.172325134277344e-7,1.4149998426437378],"Size":[9.259999752044678,0.8635447025299072,2.830000162124634],"Color":"694537","Material":"SmoothPlastic"},{"Name":"Fence_Bridge1_Caps","Center":[0,-4.172325134277344e-7,2.914999842643738],"Size":[9.420000076293945,1.0235446691513062,0.17000031471252441],"Color":"B98A5C","Material":"SmoothPlastic"}]},"Fence_Bridge2":{"Position":[0,3,-79.99925231933594],"Yaw":0,"Meshes":[{"Name":"Fence_Bridge2_Rails","Center":[-0.0000026226043701171875,0.00015461444854736328,1.5000000447034836],"Size":[11.547659397125244,6.059710741043091,3.800000101327896],"Color":"855439","Material":"SmoothPlastic"},{"Name":"Fence_Bridge2_Posts","Center":[0,0,1.4149999618530273],"Size":[9.260002136230469,0.8648582100868225,2.8300018310546875],"Color":"694537","Material":"SmoothPlastic"},{"Name":"Fence_Bridge2_Caps","Center":[0,0,2.9149999618530273],"Size":[9.420001983642578,1.0248581171035767,0.17000198364257812],"Color":"B98A5C","Material":"SmoothPlastic"}]},"Fence_Bridge3":{"Position":[0,5,-129.80062866210938],"Yaw":0,"Meshes":[{"Name":"Fence_Bridge3_Rails","Center":[-0.000051975250244140625,-0.0006219148635864258,1.5000000447034836],"Size":[11.553391456604004,6.44507098197937,3.800000101327896],"Color":"855439","Material":"SmoothPlastic"},{"Name":"Fence_Bridge3_Posts","Center":[4.76837158203125e-7,-0.000009104609489440918,1.4149994850158691],"Size":[9.260003089904785,0.8612271249294281,2.830002784729004],"Color":"694537","Material":"SmoothPlastic"},{"Name":"Fence_Bridge3_Caps","Center":[4.76837158203125e-7,-0.00000908970832824707,2.914999485015869],"Size":[9.420002937316895,1.0212270617485046,0.17000293731689453],"Color":"B98A5C","Material":"SmoothPlastic"}]},"Fence_Bridge4":{"Position":[1.1920928955078125e-7,7.5,-179.89242553710938],"Yaw":0,"Meshes":[{"Name":"Fence_Bridge4_Rails","Center":[-0.00018310546875,0.008918523788452148,1.5000000596046448],"Size":[11.55315113067627,6.446630001068115,4.800000071525574],"Color":"855439","Material":"SmoothPlastic"},{"Name":"Fence_Bridge4_Posts","Center":[-0.0000011920928955078125,0.000002682209014892578,1.4150012731552124],"Size":[9.26000165939331,0.8778276443481445,2.830002546310425],"Color":"694537","Material":"SmoothPlastic"},{"Name":"Fence_Bridge4_Caps","Center":[-9.5367431640625e-7,0.000002682209014892578,2.9150012731552124],"Size":[9.420001983642578,1.0378276109695435,0.17000269889831543],"Color":"B98A5C","Material":"SmoothPlastic"}]}}]==])
local SS = game:GetService("ServerStorage")
local lobby = workspace.Lobby
local props = lobby.GlassClashProps
local unsorted = SS:FindFirstChild("Unsorted")
assert(unsorted and not unsorted:FindFirstChild("LobbyV2Backup"), "Backup/install already exists")
assert(not lobby:FindFirstChild("FenceVisualsV2"), "Fence visuals already installed")
local raw = {}
for name, data in Data do
	local model = workspace:FindFirstChild(name)
	assert(model and model:IsA("Model"), "Missing import " .. name)
	local count = 0
	for _, p in model:GetDescendants() do
		assert(not p:IsA("LuaSourceContainer"), "Unexpected script in import")
		if p:IsA("MeshPart") then count += 1 end
	end
	assert(count == #data.Meshes, "Mesh count differs: " .. name)
	for _, e in data.Meshes do
		local p = model:FindFirstChild(e.Name, true)
		assert(p and p:IsA("MeshPart"), "Missing mesh " .. e.Name)
		local target = Vector3.new(e.Size[1], e.Size[3], e.Size[2])
		local ratios = {p.Size.X / target.X, p.Size.Y / target.Y, p.Size.Z / target.Z}
		assert(math.max(table.unpack(ratios)) / math.min(table.unpack(ratios)) < 1.001, "Nonuniform import " .. e.Name)
		assert(p.CFrame.Rotation:FuzzyEq(CFrame.identity, 0.001), "Unexpected import rotation")
	end
	raw[name] = model
end
local backup = Instance.new("Folder")
backup.Name, backup.Parent = "LobbyV2Backup", unsorted
backup:SetAttribute("InstalledAtUTC", os.date("!%Y-%m-%dT%H:%M:%SZ"))
local snapshot = Instance.new("Folder")
snapshot.Name, snapshot.Parent = "LobbyBefore", backup
for _, child in lobby:GetChildren() do
	local clone = child:Clone()
	clone.Parent = snapshot
	task.wait()
end
local sources = Instance.new("Folder")
sources.Name, sources.Parent = "RawImports", backup
for _, model in raw do model.Parent = sources end
local archive = Instance.new("Folder")
archive.Name, archive.Parent = "ReplacedVisuals", backup
local art = Instance.new("Folder")
art.Name, art.Parent = "FenceVisualsV2", lobby
local report = {Assets = {}, Backup = backup:GetFullName(), OldFenceVisuals = 0, SafetyColliders = 0, Meshes = 0}
local function v(a) return Vector3.new(a[1], a[2], a[3]) end
for name, data in Data do
	local target = CFrame.new(v(data.Position)) * CFrame.Angles(0, math.rad(data.Yaw), 0)
	local model = Instance.new("Model")
	model.Name, model.WorldPivot = name, target
	model:SetAttribute("GeneratedBy", "GlassClashLobbyV2")
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local rows = {}
	for _, e in data.Meshes do
		local p = raw[name]:FindFirstChild(e.Name, true):Clone()
		p.Size = Vector3.new(e.Size[1], e.Size[3], e.Size[2])
		-- Native importer baked a 180-degree yaw: named +X source pieces imported at -X.
		-- Restore the geometry orientation as well as its measured center and size.
		local center = Vector3.new(e.Center[1], e.Center[3], -e.Center[2])
		p.CFrame = target * CFrame.new(center) * CFrame.Angles(0, math.pi, 0)
		p.PivotOffset = p.CFrame:ToObjectSpace(target)
		p.Color, p.Material = Color3.fromHex(e.Color), Enum.Material[e.Material]
		p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
		p.Transparency, p.Reflectance, p.CastShadow, p.TextureID = 0, 0, true, ""
		for _, child in p:GetChildren() do
			if child:IsA("SurfaceAppearance") then child:Destroy() end
		end
		p:SetAttribute("LobbyV2Mesh", true)
		p.Parent = model
		rows[e.Name] = {MeshId = p.MeshId, Size = {p.Size.X, p.Size.Y, p.Size.Z}, CFrame = {p.CFrame:GetComponents()}}
		report.Meshes += 1
	end
	if name:sub(1, 6) == "Fence_" then
		model.Parent = art
	elseif name == "Kiln_Furnace" then
		model.Name, model.Parent = "VisualsV2", props.Kiln
	else
		local metric = name:sub(7)
		model.Name, model.Parent = "VisualsV2", props["Leaderboard_" .. metric]
	end
	report.Assets[name] = {Path = model:GetFullName(), Origin = data.Position, Yaw = data.Yaw, Meshes = rows}
	task.wait()
end
-- The complete previous lobby remains recoverable; hide only its old fence visuals.
for _, p in lobby.Fences:GetDescendants() do
	if p:IsA("BasePart") then
		if p.Name == "SafetyCollider" then
			assert(p.CanCollide and p.Transparency == 1, "Invalid original safety collider")
			report.SafetyColliders += 1
		else
			p:SetAttribute("LobbyV2PreviousTransparency", p.Transparency)
			p.Transparency = 1
			p.CanCollide, p.CanTouch, p.CanQuery = false, false, false
			report.OldFenceVisuals += 1
		end
	end
end
local function carrier(parent, name, size, cf)
	local p = Instance.new("Part")
	p.Name, p.Size, p.CFrame = name, size, cf
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.Transparency = true, false, false, false, 1
	p.Parent = parent
	return p
end
local function surface(parent, name, canvas)
	local gui = Instance.new("SurfaceGui")
	gui.Name, gui.Face, gui.CanvasSize = name, Enum.NormalId.Front, canvas
	gui.AlwaysOnTop, gui.LightInfluence, gui.MaxDistance = false, 0, 120
	gui.Parent = parent
	return gui
end
local function label(parent, copy)
	local t = Instance.new("TextLabel")
	t.Name, t.Text, t.Size, t.Position = "Title", copy, UDim2.fromScale(.94,.9), UDim2.fromScale(.03,.05)
	t.BackgroundTransparency, t.TextScaled = 1, true
	t.TextColor3 = Color3.fromHex("F4EBD5")
	t.FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Bold)
	t.Parent = parent
	return t
end
-- Keep the existing Kiln root, prompt and title objects that services discover.
local kiln = props.Kiln
local interaction = kiln.Interaction
for _, p in kiln:GetChildren() do
	if p:IsA("BasePart") and p ~= interaction then p.Parent = archive end
end
kiln.PrimaryPart = interaction
interaction.Size, interaction.CFrame = Vector3.new(4,4,1), CFrame.new(-22,2.5,-6.8)
local title = interaction:FindFirstChild("KilnTitle")
if title then title.StudsOffsetWorldSpace = Vector3.new(0,10.5,-4.2) end
local plaque = carrier(kiln, "HeaderCarrier", Vector3.new(4.15,.7,.05), CFrame.new(-22,7.95,-7.025)*CFrame.Angles(0,math.pi,0))
label(surface(plaque,"Header",Vector2.new(640,130)),"THE KILN")
local display = carrier(kiln, "OddsSignCarrier", Vector3.new(1.85,2.15,.04), CFrame.new(-16.75,4.3,-8.25)*CFrame.Angles(0,math.pi,0))
local copy=label(surface(display,"Information",Vector2.new(370,430)),"COIN PULLS\n\nODDS SHOWN\nBEFORE EVERY PULL")
copy.Size, copy.Position = UDim2.fromScale(.88,.88), UDim2.fromScale(.06,.06)
local seat = Instance.new("Attachment")
seat.Name, seat.WorldPosition, seat.Parent = "RevealSeat", Vector3.new(-22,2.29,-6.98), interaction
seat.WorldPosition = Vector3.new(-22,2.29,-6.98)
-- Invisible simple collision protects the furnace body without covering the approach.
local bodyCollider=carrier(kiln,"BodyCollider",Vector3.new(9.2,7,6.4),CFrame.new(-22,3.55,-12))
bodyCollider.CanCollide,bodyCollider.CanQuery=true,true
local trayCollider=carrier(kiln,"TrayCollider",Vector3.new(4.9,2.15,3.5),CFrame.new(-22,1.125,-7.65))
trayCollider.CanCollide,trayCollider.CanQuery=true,true
-- Preserve live Entries labels; move their existing Title to an editable header GUI.
for _, spec in {{ "MatchWins",-14 },{"Shatters",14},{"Trophies",28}} do
	local metric,x=spec[1],spec[2]
	local model=props["Leaderboard_"..metric]
	local board=model.Board
	local gui=board:FindFirstChildWhichIsA("SurfaceGui")
	assert(gui and gui:FindFirstChild("Entries") and gui:FindFirstChild("Title"),"Missing board binding")
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") and p~=board then p.Parent=archive end
	end
	board.Size,board.CFrame=Vector3.new(10,7.7,.08),CFrame.new(x,6.2,20.58)
	board.Transparency,board.CanCollide,board.CanTouch,board.CanQuery=1,false,false,false
	gui.Face,gui.AlwaysOnTop,gui.LightInfluence,gui.MaxDistance=Enum.NormalId.Front,false,0,120
	gui.CanvasSize=Vector2.new(900,700)
	local entries=gui.Entries
	entries.Size,entries.Position=UDim2.fromScale(.90,.90),UDim2.fromScale(.05,.05)
	entries.TextXAlignment,entries.TextYAlignment=Enum.TextXAlignment.Left,Enum.TextYAlignment.Top
	local limit=entries:FindFirstChildWhichIsA("UITextSizeConstraint") or Instance.new("UITextSizeConstraint")
	limit.MinTextSize,limit.MaxTextSize,limit.Parent=18,48,entries
	local header=carrier(model,"HeaderCarrier",Vector3.new(9.4,.68,.05),CFrame.new(x,11.0,20.40))
	local headerGui=surface(header,"Header",Vector2.new(940,95))
	local t=gui.Title
	t.Parent,t.Size,t.Position=headerGui,UDim2.fromScale(.96,.9),UDim2.fromScale(.02,.05)
	t.TextColor3=Color3.fromHex("F4EBD5")
	model.PrimaryPart=board
end
game:GetService("ChangeHistoryService"):SetWaypoint("Install lobby v2 art with backups")
report.Prompt=interaction.OpenKiln:GetFullName()
return report

