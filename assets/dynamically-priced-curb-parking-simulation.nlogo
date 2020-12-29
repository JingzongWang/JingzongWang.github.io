breed [drivers driver]
globals [ n dist_ticker dist_day day total_revenue fee_mean_inside fee_mean_outside list_of_total_distance ]


patches-own
 [
  landuse ; street/interaction/parking//residential/office
  CBD
  parking
  parking_area
  destination
  occupied ;0/1
  targeted ;0/1
  fee ; $/h
  total_fee ; for a day
  occupancy_rate ;for the whole side of one block
  walking_time_d1 ;walking time to destination 1
  walking_time_d2 ;walking time to destination 2
  walking_time_d3 ;walking time to destination 3
  walking_time_d4 ;walking time to destination 4
  cost
 ]

drivers-own
 [
  VOT
  drive_dist
  walktime
  originx
  originy
  target_x
  target_y
 ]


to setup
  ca
  resize-world -27 27 -27 27
  set-patch-size 10
  set day 0
; set landuse
 ; set street
  ask patches
    [
      if (abs pxcor + 1) mod 13 < 3 or  (abs pycor + 1) mod 13 < 3
        [set landuse "street"]
    ]
 ; set office
  ask patches with [landuse != "street" and abs pxcor < 13 and abs pycor < 13]
    [set landuse "office" ]
 ; set residential
  ask patches with [landuse != "street" and landuse != "office"]
    [set landuse "residential" ]
 ; set CBD
  ask patches [set CBD 0]
  ask patches with [(abs pxcor < 13) and (abs pycor < 13)]
    [set CBD 1]

 ; set destination
  set n 1
  ask patches [set destination 0]
  while [n < 5]
  [
    ask one-of patches with [CBD = 1 and (abs pxcor - 5) mod 13 < 1 and (abs pycor - 5) mod 13 < 1 and destination = 0]
      [
        set destination n
      ]
    set n n + 1
  ]
 ; set parking
  ask patches [set parking 0]
  ask patches with [CBD = 1 and (
    (((abs pxcor + 1) mod 13 = 0 or (abs pxcor + 1) mod 13 = 2) and ((abs pycor - 2) mod 13 < 10)) or
    (((abs pycor + 1) mod 13 = 0 or (abs pycor + 1) mod 13 = 2) and ((abs pxcor - 2) mod 13 < 10)))]
    [
      set parking 1
      set occupancy_rate -1
      set fee 2
      set total_fee fee * parking_time
      set walking_time_d1 (abs (pxcor - [pxcor] of one-of patches with [destination = 1]) + abs (pycor - [pycor] of one-of patches with [destination = 1])) * 20 / 5000
      set walking_time_d2 (abs (pxcor - [pxcor] of one-of patches with [destination = 2]) + abs (pycor - [pycor] of one-of patches with [destination = 2])) * 20 / 5000
      set walking_time_d3 (abs (pxcor - [pxcor] of one-of patches with [destination = 3]) + abs (pycor - [pycor] of one-of patches with [destination = 3])) * 20 / 5000
      set walking_time_d4 (abs (pxcor - [pxcor] of one-of patches with [destination = 4]) + abs (pycor - [pycor] of one-of patches with [destination = 4])) * 20 / 5000
    ]
  update-patch-color

; drivers
  create-drivers count patches with [parking = 1]
    [
      set color white
      set size 1
     ; set dstn (random 16) + 1
      move-to one-of patches with
        [
          CBD = 0 and
          landuse = "street" and
          count drivers-here = 0
        ]
     ]
  ask drivers [
    set VOT random-normal VOT_mean 8
    set originx xcor
    set originy ycor
  ]

  set n 0
  while [n < count drivers]
    [
      ask patches with [parking = 1] [set cost 99]
      ask driver n
        [
          let a_p patches with [parking = 1]
          ask a_p [
            (ifelse
              n mod 4 + 1 = 1 [ set cost walking_time_d1 ]
              n mod 4 + 1 = 2 [ set cost walking_time_d2 ]
              n mod 4 + 1 = 3 [ set cost walking_time_d3 ]
              n mod 4 + 1 = 4 [ set cost walking_time_d4 ])
            set cost cost * ([VOT] of driver n) + total_fee
          ]
          let p one-of a_p with-min [cost] with-min [pxcor] with-min [pycor]
            set target_x [pxcor] of p
            set target_y [pycor] of p
        ]
      set n n + 1
    ]

  ;set list to store variables
  set list_of_total_distance []
end


to update-patch-color
  ask patches with [landuse = "residential"] [set pcolor yellow]
  ask patches with [landuse = "office"] [set pcolor green]
  ask patches with [landuse = "street"] [set pcolor black]
  ask patches with [parking = 1] [set pcolor gray]
  ask patches with [destination > 0] [set pcolor orange]
end



to Next_Day
  ; set up
  show date-and-time
  reset-ticks
  set day day + 1
  set dist_ticker 0
  ask drivers
    [
      setxy originx originy
     ]
  ; Update parking fee
  ask patches with [parking = 1]
    [
      set occupied 0
      set total_fee fee * parking_time
      if occupancy_rate >= 0
        [
          if occupancy_rate > target_occ_high
            [
              set fee fee + (occupancy_rate - target_occ_high) * increment   ; increase parking fee if this street segment is overloaded
            ]
          if occupancy_rate < target_occ_low and fee > (target_occ_low - occupancy_rate) * decrement
            [
              set fee fee - ( target_occ_low - occupancy_rate) * decrement   ; decrease parking fee if this street segment is underloaded
            ]
        ]
      set pcolor scale-color red fee 3 1
    ]

  ; let all drivers drive to parking slot, record total distance and revenue
  while [ count drivers-on patches with [parking = 1] < count drivers * total_occupancy ]
    [
      set n 0
      while [n < count drivers]
        [
          ask driver n
            [
              if [parking] of patch-here != 1
                [
                  if [occupied] of one-of patches with [(pxcor = [target_x] of driver n) and (pycor = [target_y] of driver n)] = 1   ; Check if the target parking slot is occupied, find a new one if it is
                    [
                      let a_p patches with [parking = 1 and occupied = 0]
                      ask a_p    ; Calculate total cost for each slot.
                      [
                        (ifelse
                          n mod 4 + 1 = 1 [ set cost walking_time_d1 ]
                          n mod 4 + 1 = 2 [ set cost walking_time_d2 ]
                          n mod 4 + 1 = 3 [ set cost walking_time_d3 ]
                          n mod 4 + 1 = 4 [ set cost walking_time_d4 ])
                        set cost cost * ([VOT] of driver n) + total_fee
                      ]
                      ; Select the parking slot with minimal cost as target.
                      let p one-of a_p with-min [cost] with-min [pxcor] with-min [pycor]
                      set target_x [pxcor] of p
                      set target_y [pycor] of p
                    ]
                  let t one-of patches with [(pxcor = [target_x] of driver n) and (pycor = [target_y] of driver n)]
                  ; Move towards target parking slot.
                  let s min-one-of neighbors4 with [(landuse = "street" and parking = 0) or (pxcor = [pxcor] of t and pycor = [pycor] of t)] [distance t]
                  face s
                  fd 1
                  set dist_ticker dist_ticker + 1
                  if [parking] of patch-here = 1
                    [
                      ask patch-here [ set occupied 1 ]
                    ]
                ]
            ]
          set n n + 1
        ]
    ]
  set dist_day dist_ticker
  set list_of_total_distance lput dist_day list_of_total_distance
  set total_revenue sum [total_fee] of patches with [parking = 1 and occupied = 1]
  set fee_mean_inside (sum [fee] of patches with [(((abs pxcor - 1 ) mod 13 = 0) and ((abs pycor - 2 ) mod 13 < 10)) or (((abs pycor - 1 ) mod 13 = 0) and ((abs pxcor - 2 ) mod 13 < 10))]) / 80
  set fee_mean_outside (sum [fee] of patches with [(((abs pxcor + 1 ) mod 13 = 0) and ((abs pycor - 2 ) mod 13 < 10)) or (((abs pycor + 1 ) mod 13 = 0) and ((abs pxcor - 2 ) mod 13 < 10))]) / 80
  show date-and-time
  show "day:"
  show day
  show "Total distance today:"
  show dist_day
  show "Total revenue today:"
  show total_revenue
  show "inner loop parking fee:"
  show fee_mean_inside
  show "outer loop parking fee:"
  show fee_mean_outside

  ;calculate occupancy_rate for each side of each block
  ask patches with [parking = 1]
    [
      let x pxcor
      let y pycor
      if (abs pxcor + 1) mod 13 = 0 or (abs pxcor + 1) mod 13 = 2
        [
          set occupancy_rate (sum [occupied] of patches with [ parking = 1 and pxcor = x and pycor / ( abs pycor ) = y / ( abs y )]) / 10
        ]
      if (abs pycor + 1) mod 13 = 0 or (abs pycor + 1) mod 13 = 2
        [
          set occupancy_rate (sum [occupied] of patches with [ parking = 1 and pycor = y and pxcor / ( abs pxcor ) = x / ( abs x )]) / 10
        ]
    ]
  tick
end

to Keep_going
  while [ day < 15 or (item (day - 15) list_of_total_distance > min list_of_total_distance) and day < 50 ]
    [next_Day]
end
@#$#@#$#@
GRAPHICS-WINDOW
211
50
769
609
-1
-1
10.0
1
15
1
1
1
0
1
1
1
-27
27
-27
27
0
0
1
ticks
30.0

BUTTON
62
50
125
83
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
15
216
187
249
total_occupancy
total_occupancy
0.5
0.8
0.8
0.05
1
NIL
HORIZONTAL

SLIDER
15
267
187
300
VOT_mean
VOT_mean
10
20
10.0
0.5
1
NIL
HORIZONTAL

SLIDER
15
320
187
353
parking_time
parking_time
2
8
4.0
1
1
NIL
HORIZONTAL

BUTTON
51
103
136
136
NIL
next_day
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
15
384
187
417
increment
increment
0
1
0.3
0.1
1
NIL
HORIZONTAL

SLIDER
16
436
188
469
decrement
decrement
0
1
0.9
0.1
1
NIL
HORIZONTAL

SLIDER
17
498
189
531
target_occ_high
target_occ_high
0.75
0.95
0.9
0.05
1
NIL
HORIZONTAL

SLIDER
17
547
189
580
target_occ_low
target_occ_low
0.3
0.65
0.6
0.05
1
NIL
HORIZONTAL

PLOT
797
50
1086
237
Total Distance per Day
Day
Total Travel Distance
1.0
50.0
0.0
8000.0
false
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plotxy day dist_day"

PLOT
798
250
1090
415
Total Parking Revenue
Day
Total Revenue
1.0
50.0
0.0
1300.0
false
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plotxy day total_revenue"

PLOT
797
430
1218
612
Parking Fee
Day
Average Parking  Fee
1.0
50.0
1.5
2.5
false
true
"" ""
PENS
"inner loop parking fee" 1.0 0 -4757638 true "" "plotxy day fee_mean_inside\n"
"Outer loop parking fee" 1.0 0 -13791810 true "" "plotxy day fee_mean_outside"

BUTTON
45
155
140
188
NIL
keep_going
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

@#$#@#$#@
## WHAT IS IT?

This model is a simulation of dynamically-priced curb parking. This strategy was commonly designed to manage parking cogestion through price manipulation in order to optimize occupancy and reduce traffic congestion (Fichman 2016).  

## HOW IT WORKS

### About the World
The center of this world is commercial area (green patches) with four job destinations and 160 curb parking slots. There are also 160 commuters who randomly live in residential area and have differnt Value of Time (VOT).

### Dynamic Process
Everyday, commuters will try to reach a parking slot near their destination and with low parking fee. Once the total occupancy rate reach the total occupancy rate, the day will end. Occupancy rates for each side of commerical blocks will calcualted and for the next day, the parking fee will be increased or decreased based on them.The original parking fee is 2$/hr.

### Statistics
For each day, total travel distance will be recorded as a measure of congestion. Total parking revenue will also be recorded.

 
## HOW TO USE IT

### Setup
Setup the world before run next_day or keep_going

### Next_day
Start next day
The color of parking slots represent the parking fee. (white-red-black : 1.5-2-2.5)

### keep_going
keep runing next day until total distance touches bottom on the 15 days before today. This ending condition was designed to ensure the shortest total distance has been found.

### parameter

There are several varaibles could be adjusted:

1. Total occupancy      
2. VOT mean             mean of VOT (the overall VOT obeys a normal distribution with standard deviation of 8
3. Parking time (hr)
4. increment            if the occupancy rate is higher the target range, the parking fee will increase  increment*(occupancy_rate-target_occupancy_high)
5. decrement            similar as increment
6. target_ooc_high/low  target occupancy range 

 

## THINGS TO NOTICE
1. setup before run next_day or keep_going
2. you should always set up after change any parameter
3. total occupancy should be within target range
4. If the total occupancy is very high, there is a chance that some drivers can't find parking slots due to the problem of our pathfinding algortithm.



## THINGS TO TRY

Adjust several parameters to see under what conditions the total distance will decrease and how the total revenue will change accordingly. 


## EXTENDING THE MODEL

1. Better pathfinding algorithm could be incorporated in this model.
2. Driving time could be taken into consideration when drivers choose their targeted parking slots.
3. Add drivers with other purpose like shopping.
4. Add competitive travel modes:
5. If the parking fee keeps increasing, people may take alternative transit methods instead of driving. This model doesn’t include this scenario. To improve this model, we could change the total parking cars based on parking fees. In other words, there will be fewer driving cars if parking fee is too high and cheap parking lots are not enough. 
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.1.1
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
