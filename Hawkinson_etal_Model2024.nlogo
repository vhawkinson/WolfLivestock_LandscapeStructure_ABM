globals [
  day
  patch-count
  number-of-patches-avail
  global-frag-number
  fragment-start
  setup-available-patches
  time-since-meal
  leader-farm
  leader-death
  cow-death
  elk-death
  cow-pasture-death
  cow-forest-death
  elk-pasture-death
  elk-forest-death
  cow-edge-death
  cow-interior-death
  elk-edge-death
  elk-interior-death
  ]

breed [ cows cow ]
breed [ wolves wolf ]
breed [ elk an-elk ]
breed [ farms a-farm ]

patches-own [
  patch-avail
  patch-meals
  pasture-meals
  meals
  connectivity
  interior
  edge
  fragment-number
  possible?
  habitat?
  habitat-ID
  tagged
  wolf-pass
]

cows-own [
  wolf-encounter
  herd-leader?
  my-herd-leader
]

wolves-own [
  pack-leader?
  leader-wolf
]

turtles-own [
  farm-number
  farm-distance
  farm-x
  farm-y
  my-farm
]

to setup
  clear-all
  set global-frag-number 1
  set patch-count count patches
  set number-of-patches-avail (patch-count * (patch-availability / 100))
  ask patches [set possible? true
  set habitat? false]
  setup-patches
  grow-patches
  connect
  setup-wolves
  setup-elk
  setup-farms
  set day 0
  reset-ticks
end


to setup-patches ; seeds the number of fragments selected in the slider bar (0 - 20) and assigns a number to each one
  while [ count patches with [ pcolor = green ] < number-fragments ]
  [ask one-of patches with [ pcolor != green and count neighbors with [ pcolor = green ] = 0 ]
    [set pcolor  green
      set fragment-number global-frag-number
      set   habitat? true
     ]
     set global-frag-number global-frag-number + 1 ]
end


to grow-patches ; expands the fragments by checking patches in a radius of 1 and adding layers - also sets the distance between different fragments so they don't overlap
 while [ count patches with [ pcolor = green ] < number-of-patches-avail ]
[  ask one-of patches with [habitat? = true] [
    let already-habitats other patches with [ habitat? = true and fragment-number != [fragment-number] of myself  ]
    ask already-habitats [
      set pcolor green
      let not-possible other patches in-radius 4 with [pcolor != green] ; here is where you can set the corridors between fragments to be bigger or smaller!
      ask not-possible [
     set possible? false]]
    let possible-patches other patches in-radius 1 with [possible? = true]
    ask possible-patches [
    set  fragment-number  [fragment-number] of myself
   set habitat? true ]
  ]
  ask patches with [habitat? = false and possible? = false] [ set possible? true ]
  ]

  ask patches [
  set patch-avail 0
    ifelse (habitat? = true) [set patch-avail 1] [ set patch-avail 0 ]
    set meals random 1000 + 1 ; randomly assigns a meals value to each patch - indicative of the amount of forage/degradation that patch has
    if patch-avail = 1 [ set patch-meals meals ]
    if patch-avail = 0 [ set pasture-meals meals ]
    ]
  set-patch-color

end

to set-patch-color ; uses the availability and meals numbers to assign colors (brown or green) to the patches
  ask patches [
if patch-avail = 0 [ set pcolor brown ]
if patch-avail = 1 [ set pcolor green ]
   ;if patch-avail = 0 [ set pcolor scale-color brown pasture-meals 0 101 ] ; unsuitable patches are assigned a color on the brown scale according to their meals value
   ;if patch-avail = 1 [ set pcolor scale-color green patch-meals 0 101 ] ; the suitable patches are assigned a color on the green scale according to their meals value
  ]
end


to connect ; looks at the interconnectedness of the available patches to provide information on the amount of habitat that is edge vs. interior
  ask patches [
   set connectivity 0
   if patch-avail = 1 [
      set connectivity count neighbors with [ patch-avail = 1 ]]
  ]
  ask patches [
  if connectivity = 8 [
    set interior 1 ]
  ]
  ask patches [
    if connectivity != 8 AND patch-avail = 1
    [ set edge 1 ]
  ]
  type "percentage of interior: " print round((count patches with [ interior = 1 ] / (count patches with [patch-avail = 1])) * 100)
  type "percentage of edge: " print round((count patches with [ edge = 1 ] / (count patches with [patch-avail = 1])) * 100)
end

to setup-wolves ; wolves are created only on patches of "available" habitat aka public land
  create-wolves 1
  ask wolves
  [
  move-to one-of patches with [ patch-avail = 1 ]
  set shape "wolf"
  set color pink
  set size 2
  set time-since-meal 0
  set pack-leader? true
    pick-wolf-patch
    hatch-wolves number-wolves - 1 [
      set shape "wolf"
      set color yellow
      set size 2
      set pack-leader? false
  ]
  ]
end


to pick-wolf-patch ; this selects the fragment that the wolves are going to start out on - it's randomly selected
  set fragment-start random number-fragments + 1
  ask wolves [
    move-to one-of patches with [ fragment-number = fragment-start ]
  ]
end

to setup-elk ; elk are created only on patches of "available" habitat aka public land
  create-elk number-elk
  ask elk
  [
  move-to one-of patches with [ patch-avail = 1 ]
  set shape "moose"
  set color orange
  set size 2
  ]
end


to setup-farms ;this creates the "farm" buildings on the pastures, and hatches cows on the same patch as each farm as their starting point.
  create-farms number-farms
  ask farms
  [
    move-to one-of patches with [patch-avail = 0]
    while [any? other farms in-radius 10] [
      setxy random-xcor random-ycor
      move-to min-one-of patches with [patch-avail = 0] [distance myself]
    ]
    set shape "house"
    set color pink
    set size 3
    set farm-number who
     hatch-cows 1 [
      set shape "cow"
      set color blue
      set size 2
      set herd-leader? true
      if (any? farms-here) [
        set farm-number farm-number
        set my-farm [ farm-number ] of myself
      set farm-x [xcor] of myself
      set farm-y [ycor] of myself
        ]
        ]
    hatch-cows herd-size - 1 [
  set shape "cow"
  set color red
  set size 2
      set herd-leader? false
  if (any? farms-here) [
        set my-farm farm-number
        set my-herd-leader min-one-of cows with [(herd-leader? = true) and (farm-number = my-farm)] [distance myself]
      ]
    ]
    ]
end


to go
  move-wolves
  move-elk
  move-cows
  set day day + 1
  set time-since-meal time-since-meal + 1
  if day >= 366 [stop]
  tick
end

to move-wolves
  ask wolves [
  if pack-leader? = true [
      fear-farms
      hunt
      eat-elk
      eat-cows ]
  if pack-leader? = false [
      follow-pack-leader
    ]
  ]
end

;when a wolf kills wild prey, the model is set to print the type of landscape (forest vs. pasture) the prey was killed on,
;and if that patch was forest, whether the patch was interior or edge
;also contributes to the counter on the main screen tracking wild prey deaths

to eat-elk ; wolves eating wild prey
  ask wolves [
  let ungulate-prey one-of elk-here
  if (ungulate-prey != nobody and time-since-meal > 2) [
    ask ungulate-prey [ set elk-death elk-death + 1 ]
    ask ungulate-prey [ die ]
    set time-since-meal 0
      ifelse (patch-avail = 1) [
        set elk-forest-death elk-forest-death + 1 ]
      [ set elk-pasture-death elk-pasture-death + 1 ]
    if (patch-avail = 1) [
        if (interior = 1) [
          set elk-interior-death elk-interior-death + 1]
        if (edge = 1) [
          set elk-edge-death elk-edge-death + 1]
      ]
  ]
  ]
end

;when a wolf kills a cow, the model is set to print the distance that the cow is from the farm that "hatched" it, in addition to the type of landscape (forest vs. pasture)
;and whether that patch was interior or edge, if it was forest
;also contributes to the counter on the main screen tracking livestock deaths

to eat-cows ; wolves eating livestock
  ask wolves [
    let livestock-prey one-of cows-here
  if (livestock-prey != nobody and time-since-meal > 2) [
      let current-herd [my-farm] of livestock-prey
      let home-farm one-of farms with [farm-number = current-herd]
      let farmx [xcor] of home-farm
      let farmy [ycor] of home-farm
      ask livestock-prey [ show round(distancexy farmx farmy) ]
      ask livestock-prey [ set cow-death cow-death + 1]
      ask livestock-prey [
          if herd-leader? = true [
            set leader-death leader-death + 1
            ask min-one-of cows with [my-farm = current-herd] [distance myself] [
            set herd-leader? true
              set color blue ]]]
      ask livestock-prey [ die ]
      ask cows [
                if herd-leader? = false [
                  set my-herd-leader min-one-of cows with [(herd-leader? = true) and (farm-number = my-farm)] [distance myself] ] ]
      set time-since-meal 0
ifelse (patch-avail = 1) [
        set cow-forest-death cow-forest-death + 1 ]
      [ set cow-pasture-death cow-pasture-death + 1]
    if (patch-avail = 1) [
        if (interior = 1) [
          set cow-interior-death cow-interior-death + 1]
        if (edge = 1) [
          set cow-edge-death cow-edge-death + 1]
      ]
        ]
  ]
end


; starting to implement some of the wolf movement rules here
; wolves look around them in a cone to see if they see elk, and if not they check for livestock. If they see either, they hunt it, elk first, then cattle

to hunt
  let prey turtles with [ breed = elk and breed = cows  ]
  ask wolves [
    let candidate-prey nobody
    let prey-in-view prey in-cone 4 360
    let target-heading 0
    if (any? prey-in-view and time-since-meal > 2) [
      set candidate-prey one-of prey-in-view with-min [distance myself]
      set target-heading towards candidate-prey
      set heading target-heading
      fd 2
      ]
    if (any? prey-in-view and time-since-meal <= 2) [
    rt random-float 360
    fd 2 ]
    if (not any? prey-in-view) [
    rt random-float 360
    fd 4 ]
      ]
end



to fear-farms ; the wolves won't get too close to the farm buildings when walking out of fear
  ask wolves[
    ifelse wolf-fear? [
   let candidate-farm nobody
   let farms-in-view farms in-cone 2 360
   let target-heading 0
    ifelse (any? farms-in-view) [
        set candidate-farm one-of farms-in-view with-min [distance myself]
      set target-heading (180 + towards candidate-farm)
      set heading target-heading
      fd 2
      set label "!"
  ]
    [set label ""]
    ]
    [set label ""]
  ]
end

to follow-pack-leader
  ask wolves [
    let pack-leader wolves with [pack-leader? = true] ;; find pack leader
    let target-heading 0 ; set up the target heading for the packing action
    if (pack-leader? = false) [
    set leader-wolf min-one-of wolves with [pack-leader? = true] [distance myself] ; sets the closest leader to be which ever leader is closest
    ifelse any? pack-leader in-radius pack-elasticity [
      fear-farms
      hunt
      eat-elk
      eat-cows ] ; if there are any leaders within the number of patches defined by the elasticity slider, they use a random walk
    [ set target-heading towards leader-wolf
      set heading target-heading
      fd pack-elasticity ] ; if not, then they move toward the pack leader
  ]
  ]
end


;elk movement is driven by the patch near them with the highest available forage.
;If the patch they are on has the highest forage within their neighboring patches, they randomly move 2 patches over

to move-elk
  ask elk [
    elk-fear-wolves
    move-to max-one-of neighbors [meals]
      if not can-move? 1 [
      rt random-float 360
      fd 2]
    eat-food
  ]
end

;if the elk see wolves within a 1 patch radius and 180 degree cone, they will turn the opposite direction out of fear

to elk-fear-wolves
  ask elk [
  let candidate-wolves nobody
    let target-heading 0
    ifelse fear? [
    let wolves-in-view wolves in-cone 1 360
    ifelse any? wolves-in-view [
      set candidate-wolves one-of wolves-in-view
      set target-heading 180 + towards candidate-wolves
      set heading target-heading
      fd 1
      set label "OH NO"
  ]
    [ set label ""]
  ]
    [set label ""]
  ]
end

;if the wild prey get too close to the livestock, they will turn away before moving to their next patch
;if there are cattle on multiple sides of the elk, what will they do? This shouldn't be a problem if the cattle are acting in a herd, but right now they aren't so this is giving some issues.

;to elk-avoid-livestock
;  ask elk [
;  let cattle-near cows in-radius 1
;  let target-heading 0
;    if (any? cattle-near) [
;  let close-cattle min-one-of cattle-near [distance myself]
;  if (any? close-cattle) [
;    set target-heading 180 + towards cattle-near
;    ]
;    ]
;  ]
;end

;command for the elk to eat both forest forage and pasture forage

to eat-food
ask elk [
  if ( meals >= 1 and patch-avail = 1) [
    set patch-meals patch-meals - 1
    set meals meals - 1
      ]
    if (meals >= 1 and patch-avail = 0)[
    set pasture-meals pasture-meals - 1
    set meals meals - 1
  ]
  ]
end


;depending on the treatment (free roaming, pasture-limited, or herded) the cattle access different patches but are ultimately still driven by high forage values
;they have the same option as the elk to jump 2 patches over if they get stranded on their patch because everything around them has lower meals values

to move-cows
  ;bounce
  ask cows [
      if (cattle-treatment = "cattle-everywhere") [
      if herd-leader? = true [
        cows-fear-wolves
      move-to max-one-of neighbors [meals]
      if not can-move? 1 [
      rt random-float 360
      fd 2]
      graze-all
  ]
      if herd-leader? = false [
        follow-herd-leader-all
      ]
    ]
    if (cattle-treatment = "cattle-pasture") [
      if herd-leader? = true [
        cows-fear-wolves
      move-to max-one-of neighbors [pasture-meals]
      if not can-move? 1 [
        rt random-float 360
        fd 2]
        graze-pasture
    ]
      if herd-leader? = false [
        follow-herd-leader-pasture
      ]
  ]
    if (cattle-treatment = "cattle-herded") [
      if herd-leader? = true [
        if ticks = 0 [
          move-to one-of patches with [ patch-avail = 1 ] ]
        if ticks = 183 [
          setxy farm-x farm-y]
        cows-fear-wolves
        herding-pattern
      ]
        if herd-leader? = false [
          let my-leader-cow min-one-of cows with [(farm-number = my-farm) and (herd-leader? = true)] [distance myself]
          set my-herd-leader my-leader-cow
          follow-herd-leader-herded
        ]
      ]
  ]
end

to herding-pattern
  ask cows [
    if ticks > 1 and ticks < 183 [
      cows-fear-wolves
    move-to max-one-of neighbors [patch-meals]
    if not can-move? 1 [
      rt random-float 360
      fd 2 ]
      graze-habitat
      ]
    if ticks >= 183 and ticks < 365 [
      cows-fear-wolves
      move-to max-one-of neighbors [pasture-meals]
        if not can-move? 1 [
          rt random-float 360
          fd 2 ]
      graze-pasture
      ]
  ]
end

to follow-herd-leader-all
  let target-heading 0
    ask cows [
    if (herd-leader? = false) [
    if distance my-herd-leader > herd-elasticity [
    set target-heading towards my-herd-leader
    set heading target-heading
    fd herd-elasticity]
    if distance my-herd-leader <= herd-elasticity [
    cows-fear-wolves
    move-to max-one-of neighbors [patch-meals]
    if not can-move? 1 [
    rt random-float 360
    fd 2 ]
    graze-all
    ]
    ]
    ]
end

to follow-herd-leader-pasture
   let target-heading 0
   ask cows [
    if (herd-leader? = false) [
    if distance my-herd-leader > herd-elasticity [
    set target-heading towards my-herd-leader
    set heading target-heading
    fd herd-elasticity]
    if distance my-herd-leader <= herd-elasticity [
    cows-fear-wolves
    move-to max-one-of neighbors [pasture-meals]
    if not can-move? 1 [
    rt random-float 360
    fd 2 ]
    graze-pasture
    ]
    ]
    ]
end

to follow-herd-leader-herded
  let target-heading 0
  ask cows [
    if (herd-leader? = false) [
      if ticks = 0 or ticks = 183 [
        move-to my-herd-leader ]
      if distance my-herd-leader > herd-elasticity [
        set target-heading towards my-herd-leader
        set heading target-heading
        fd herd-elasticity ]
      if distance my-herd-leader <= herd-elasticity [
        if ticks > 0 and ticks <= 182 [
        cows-fear-wolves
        move-to max-one-of neighbors [patch-meals]
          if not can-move? 1 [
          rt random-float 360
            fd 2 ]
          graze-all ]
        if ticks > 182 and ticks < 366 [
          cows-fear-wolves
          move-to max-one-of neighbors [pasture-meals]
          if not can-move? 1 [
          rt random-float 360
          fd 2 ]
          graze-pasture ]
      ]
    ]
  ]
end


;the cattle have to come within a certain view of wolves at least once to learn to fear them
;should this be changed to a cow from their herd having to die to trigger fear?

to cows-fear-wolves
  ask cows [
    if (any? wolves-here in-cone 1 180) [
        set wolf-encounter wolf-encounter + 1 ]
    if (wolf-encounter > 1) [
    let candidate-wolves nobody
    let target-heading 0
    ifelse fear? [
    let wolves-in-view wolves in-cone 1 360
    ifelse any? wolves-in-view [
      set candidate-wolves one-of wolves-in-view
      set target-heading 180 + towards candidate-wolves
      set heading target-heading
      fd 1
      set label "OH NO"
  ]
    [ set label ""]
  ]
    [set label ""]
    ]
  ]
end

;command for free roaming cattle to eat

to graze-all
  if (meals >= 1 and patch-avail = 1) [
    set patch-meals patch-meals - 1
    set meals meals - 1
      ]
     if (meals >= 1 and patch-avail = 0)[
    set pasture-meals pasture-meals - 1
    set meals meals - 1
      ]
end

;command for pasture-limited cattle to eat

to graze-pasture
    if (pasture-meals >= 1 and patch-avail = 0) [
      set pasture-meals pasture-meals - 1
      set meals meals - 1
    ]
end

;command for cattle to eat the non-pasture land

to graze-habitat
  if (patch-meals >= 1 and patch-avail = 1) [
    set patch-meals patch-meals - 1
    set meals meals - 1
  ]
end

;keeps the turtles from disappearing on one side of the world and reappearing on the other
;took this out for now because I think having a wrapped world makes more sense but can always add it back in

;to bounce
;  ask turtles [
;    if patch-ahead 1 = nobody
;       [set heading heading - 180]
;  ]
;end
@#$#@#$#@
GRAPHICS-WINDOW
238
10
852
625
-1
-1
6.0
1
10
1
1
1
0
1
1
1
0
100
0
100
0
0
1
ticks
30.0

BUTTON
10
15
76
48
setup
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

BUTTON
89
16
152
49
go
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

MONITOR
872
10
1011
55
suitable patch count
count patches with [patch-avail = 1]
17
1
11

MONITOR
876
132
933
177
day
day
17
1
11

MONITOR
13
70
107
115
NIL
count wolves
17
1
11

MONITOR
13
129
83
174
NIL
count elk
17
1
11

MONITOR
11
191
94
236
NIL
count cows
17
1
11

SLIDER
7
310
179
343
number-wolves
number-wolves
0
30
6.0
2
1
NIL
HORIZONTAL

SLIDER
6
358
178
391
number-elk
number-elk
0
800
480.0
10
1
NIL
HORIZONTAL

SLIDER
6
404
178
437
number-farms
number-farms
0
10
9.0
1
1
NIL
HORIZONTAL

SLIDER
8
256
180
289
patch-availability
patch-availability
0
100
25.0
25
1
NIL
HORIZONTAL

MONITOR
8
606
155
651
Interior-percent
(count patches with [ interior = 1 ] / (count patches with [patch-avail = 1])) * 100
3
1
11

MONITOR
6
655
155
700
edge-percent
(count patches with [ edge = 1 ] / (count patches with [patch-avail = 1])) * 100
3
1
11

SLIDER
8
457
180
490
number-fragments
number-fragments
0
20
3.0
1
1
NIL
HORIZONTAL

MONITOR
169
656
287
701
available patches
setup-available-patches
17
1
11

CHOOSER
7
505
166
550
cattle-treatment
cattle-treatment
"cattle-everywhere" "cattle-pasture" "cattle-herded"
0

SWITCH
8
564
111
597
fear?
fear?
0
1
-1000

MONITOR
93
130
232
175
NIL
global-frag-number
17
1
11

SLIDER
877
76
1049
109
herd-size
herd-size
0
200
45.0
5
1
NIL
HORIZONTAL

MONITOR
1086
27
1200
72
NIL
time-since-meal
17
1
11

SLIDER
1090
152
1262
185
pack-elasticity
pack-elasticity
0
20
4.0
1
1
NIL
HORIZONTAL

SLIDER
1093
202
1265
235
herd-elasticity
herd-elasticity
0
20
4.0
1
1
NIL
HORIZONTAL

MONITOR
1087
94
1180
139
NIL
leader-death
17
1
11

SWITCH
1100
313
1219
346
wolf-fear?
wolf-fear?
0
1
-1000

MONITOR
878
244
957
289
NIL
cow-death
17
1
11

MONITOR
877
189
949
234
NIL
elk-death
17
1
11

MONITOR
878
300
1004
345
NIL
elk-pasture-death
17
1
11

MONITOR
878
356
994
401
NIL
elk-forest-death
17
1
11

MONITOR
879
413
1012
458
NIL
cow-pasture-death
17
1
11

MONITOR
879
471
1002
516
NIL
cow-forest-death
17
1
11

MONITOR
878
524
987
569
NIL
elk-edge-death
17
1
11

MONITOR
876
579
1001
624
NIL
elk-interior-death
17
1
11

MONITOR
1013
580
1129
625
NIL
cow-edge-death
17
1
11

MONITOR
1007
524
1139
569
NIL
cow-interior-death
17
1
11

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
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

moose
false
0
Polygon -7500403 true true 196 228 198 297 180 297 178 244 166 213 136 213 106 213 79 227 73 259 50 257 49 229 38 197 26 168 26 137 46 120 101 122 147 102 181 111 217 121 256 136 294 151 286 169 256 169 241 198 211 188
Polygon -7500403 true true 74 258 87 299 63 297 49 256
Polygon -7500403 true true 25 135 15 186 10 200 23 217 25 188 35 141
Polygon -7500403 true true 270 150 253 100 231 94 213 100 208 135
Polygon -7500403 true true 225 120 204 66 207 29 185 56 178 27 171 59 150 45 165 90
Polygon -7500403 true true 225 120 249 61 241 31 265 56 272 27 280 59 300 45 285 90

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
NetLogo 6.4.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="LowAvail_HighConnect_CEverywhere" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="365"/>
    <metric>count elk</metric>
    <metric>count cows</metric>
    <metric>elk-death</metric>
    <metric>elk-forest-death</metric>
    <metric>elk-pasture-death</metric>
    <metric>elk-edge-death</metric>
    <metric>elk-interior-death</metric>
    <metric>cow-death</metric>
    <metric>cow-forest-death</metric>
    <metric>cow-pasture-death</metric>
    <metric>cow-edge-death</metric>
    <metric>cow-interior-death</metric>
    <enumeratedValueSet variable="patch-availability">
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-wolves">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-elk">
      <value value="480"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herd-size">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-farms">
      <value value="9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fear?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cattle-treatment">
      <value value="&quot;cattle-everywhere&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-fragments">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pack-elasticity">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herd-elasticity">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolf-fear?">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MedAvail_HighConnect_CEverywhere" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="365"/>
    <metric>count elk</metric>
    <metric>count cows</metric>
    <metric>elk-death</metric>
    <metric>elk-forest-death</metric>
    <metric>elk-pasture-death</metric>
    <metric>elk-edge-death</metric>
    <metric>elk-interior-death</metric>
    <metric>cow-death</metric>
    <metric>cow-forest-death</metric>
    <metric>cow-pasture-death</metric>
    <metric>cow-edge-death</metric>
    <metric>cow-interior-death</metric>
    <enumeratedValueSet variable="patch-availability">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-wolves">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-elk">
      <value value="480"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herd-size">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-farms">
      <value value="9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fear?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cattle-treatment">
      <value value="&quot;cattle-everywhere&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-fragments">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pack-elasticity">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herd-elasticity">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolf-fear?">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="HighAvail_HighConnect_CEverywhere" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="365"/>
    <metric>count elk</metric>
    <metric>count cows</metric>
    <metric>elk-death</metric>
    <metric>elk-forest-death</metric>
    <metric>elk-pasture-death</metric>
    <metric>elk-edge-death</metric>
    <metric>elk-interior-death</metric>
    <metric>cow-death</metric>
    <metric>cow-forest-death</metric>
    <metric>cow-pasture-death</metric>
    <metric>cow-edge-death</metric>
    <metric>cow-interior-death</metric>
    <enumeratedValueSet variable="patch-availability">
      <value value="75"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-wolves">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-elk">
      <value value="480"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herd-size">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-farms">
      <value value="9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fear?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cattle-treatment">
      <value value="&quot;cattle-everywhere&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-fragments">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pack-elasticity">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herd-elasticity">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolf-fear?">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="LowAvail_MedConnect_CEverywhere" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="365"/>
    <metric>count elk</metric>
    <metric>count cows</metric>
    <metric>elk-death</metric>
    <metric>elk-forest-death</metric>
    <metric>elk-pasture-death</metric>
    <metric>elk-edge-death</metric>
    <metric>elk-interior-death</metric>
    <metric>cow-death</metric>
    <metric>cow-forest-death</metric>
    <metric>cow-pasture-death</metric>
    <metric>cow-edge-death</metric>
    <metric>cow-interior-death</metric>
    <enumeratedValueSet variable="patch-availability">
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-wolves">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-elk">
      <value value="480"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herd-size">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-farms">
      <value value="9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fear?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cattle-treatment">
      <value value="&quot;cattle-everywhere&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-fragments">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pack-elasticity">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herd-elasticity">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolf-fear?">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="LowAvail_LowConnect_CPasture" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <postRun>print elk-death
print elk-forest-death
print elk-pasture-death
print elk-edge-death
print elk-interior-death
print cow-death
print cow-forest-death
print cow-pasture-death
print cow-edge-death
print cow-interior-death</postRun>
    <timeLimit steps="365"/>
    <metric>count elk</metric>
    <metric>count cows</metric>
    <metric>elk-death</metric>
    <metric>elk-forest-death</metric>
    <metric>elk-pasture-death</metric>
    <metric>elk-edge-death</metric>
    <metric>elk-interior-death</metric>
    <metric>cow-death</metric>
    <metric>cow-forest-death</metric>
    <metric>cow-pasture-death</metric>
    <metric>cow-edge-death</metric>
    <metric>cow-interior-death</metric>
    <enumeratedValueSet variable="patch-availability">
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-wolves">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-elk">
      <value value="480"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herd-size">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-farms">
      <value value="9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fear?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cattle-treatment">
      <value value="&quot;cattle-pasture&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-fragments">
      <value value="9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pack-elasticity">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herd-elasticity">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolf-fear?">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MedAvail_MedConnect_CEverywhere" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="365"/>
    <metric>count elk</metric>
    <metric>count cows</metric>
    <metric>elk-death</metric>
    <metric>elk-forest-death</metric>
    <metric>elk-pasture-death</metric>
    <metric>elk-edge-death</metric>
    <metric>elk-interior-death</metric>
    <metric>cow-death</metric>
    <metric>cow-forest-death</metric>
    <metric>cow-pasture-death</metric>
    <metric>cow-edge-death</metric>
    <metric>cow-interior-death</metric>
    <enumeratedValueSet variable="patch-availability">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-wolves">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-elk">
      <value value="480"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herd-size">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-farms">
      <value value="9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fear?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cattle-treatment">
      <value value="&quot;cattle-everywhere&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-fragments">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pack-elasticity">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herd-elasticity">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolf-fear?">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MedAvail_LowConnect_CEverywhere" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="365"/>
    <metric>count elk</metric>
    <metric>count cows</metric>
    <metric>elk-death</metric>
    <metric>elk-forest-death</metric>
    <metric>elk-pasture-death</metric>
    <metric>elk-edge-death</metric>
    <metric>elk-interior-death</metric>
    <metric>cow-death</metric>
    <metric>cow-forest-death</metric>
    <metric>cow-pasture-death</metric>
    <metric>cow-edge-death</metric>
    <metric>cow-interior-death</metric>
    <enumeratedValueSet variable="patch-availability">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-wolves">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-elk">
      <value value="480"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herd-size">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-farms">
      <value value="9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fear?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cattle-treatment">
      <value value="&quot;cattle-everywhere&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-fragments">
      <value value="9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pack-elasticity">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herd-elasticity">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolf-fear?">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="HighAvail_MedConnect_CEverywhere" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <postRun>print elk-death
print elk-forest-death
print elk-pasture-death
print elk-edge-death
print elk-interior-death
print cow-death
print cow-forest-death
print cow-pasture-death
print cow-edge-death
print cow-interior-death</postRun>
    <timeLimit steps="365"/>
    <metric>count elk</metric>
    <metric>count cows</metric>
    <metric>elk-death</metric>
    <metric>elk-forest-death</metric>
    <metric>elk-pasture-death</metric>
    <metric>elk-edge-death</metric>
    <metric>elk-interior-death</metric>
    <metric>cow-death</metric>
    <metric>cow-forest-death</metric>
    <metric>cow-pasture-death</metric>
    <metric>cow-edge-death</metric>
    <metric>cow-interior-death</metric>
    <enumeratedValueSet variable="patch-availability">
      <value value="75"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-wolves">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-elk">
      <value value="480"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herd-size">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-farms">
      <value value="9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fear?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cattle-treatment">
      <value value="&quot;cattle-everywhere&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-fragments">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pack-elasticity">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herd-elasticity">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolf-fear?">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="HighAvail_LowConnect_CEverywhere" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="365"/>
    <metric>count elk</metric>
    <metric>count cows</metric>
    <metric>elk-death</metric>
    <metric>elk-forest-death</metric>
    <metric>elk-pasture-death</metric>
    <metric>elk-edge-death</metric>
    <metric>elk-interior-death</metric>
    <metric>cow-death</metric>
    <metric>cow-forest-death</metric>
    <metric>cow-pasture-death</metric>
    <metric>cow-edge-death</metric>
    <metric>cow-interior-death</metric>
    <enumeratedValueSet variable="patch-availability">
      <value value="75"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-wolves">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-elk">
      <value value="480"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herd-size">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-farms">
      <value value="9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fear?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cattle-treatment">
      <value value="&quot;cattle-everywhere&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-fragments">
      <value value="9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pack-elasticity">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herd-elasticity">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolf-fear?">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="HighAvail_MedConnect_CPasture" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <postRun>print elk-death
print elk-forest-death
print elk-pasture-death
print elk-edge-death
print elk-interior-death
print cow-death
print cow-forest-death
print cow-pasture-death
print cow-edge-death
print cow-interior-death</postRun>
    <timeLimit steps="365"/>
    <metric>count elk</metric>
    <metric>count cows</metric>
    <metric>elk-death</metric>
    <metric>elk-forest-death</metric>
    <metric>elk-pasture-death</metric>
    <metric>elk-edge-death</metric>
    <metric>elk-interior-death</metric>
    <metric>cow-death</metric>
    <metric>cow-forest-death</metric>
    <metric>cow-pasture-death</metric>
    <metric>cow-edge-death</metric>
    <metric>cow-interior-death</metric>
    <enumeratedValueSet variable="patch-availability">
      <value value="75"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-wolves">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-elk">
      <value value="480"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herd-size">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-farms">
      <value value="9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fear?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cattle-treatment">
      <value value="&quot;cattle-pasture&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-fragments">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pack-elasticity">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herd-elasticity">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolf-fear?">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="HighAvail_MedConnect_CHerded" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <postRun>print elk-death
print elk-forest-death
print elk-pasture-death
print elk-edge-death
print elk-interior-death
print cow-death
print cow-forest-death
print cow-pasture-death
print cow-edge-death
print cow-interior-death</postRun>
    <timeLimit steps="365"/>
    <metric>count elk</metric>
    <metric>count cows</metric>
    <metric>elk-death</metric>
    <metric>elk-forest-death</metric>
    <metric>elk-pasture-death</metric>
    <metric>elk-edge-death</metric>
    <metric>elk-interior-death</metric>
    <metric>cow-death</metric>
    <metric>cow-forest-death</metric>
    <metric>cow-pasture-death</metric>
    <metric>cow-edge-death</metric>
    <metric>cow-interior-death</metric>
    <enumeratedValueSet variable="patch-availability">
      <value value="75"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-wolves">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-elk">
      <value value="480"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herd-size">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-farms">
      <value value="9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fear?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cattle-treatment">
      <value value="&quot;cattle-herded&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-fragments">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pack-elasticity">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herd-elasticity">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolf-fear?">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="HighAvail_LowConnect_CPasture" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="365"/>
    <metric>count elk</metric>
    <metric>count cows</metric>
    <metric>elk-death</metric>
    <metric>elk-forest-death</metric>
    <metric>elk-pasture-death</metric>
    <metric>elk-edge-death</metric>
    <metric>elk-interior-death</metric>
    <metric>cow-death</metric>
    <metric>cow-forest-death</metric>
    <metric>cow-pasture-death</metric>
    <metric>cow-edge-death</metric>
    <metric>cow-interior-death</metric>
    <enumeratedValueSet variable="patch-availability">
      <value value="75"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-wolves">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-elk">
      <value value="480"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herd-size">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-farms">
      <value value="9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fear?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cattle-treatment">
      <value value="&quot;cattle-pasture&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-fragments">
      <value value="9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pack-elasticity">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herd-elasticity">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolf-fear?">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="HighAvail_LowConnect_CHerded" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="365"/>
    <metric>count elk</metric>
    <metric>count cows</metric>
    <metric>elk-death</metric>
    <metric>elk-forest-death</metric>
    <metric>elk-pasture-death</metric>
    <metric>elk-edge-death</metric>
    <metric>elk-interior-death</metric>
    <metric>cow-death</metric>
    <metric>cow-forest-death</metric>
    <metric>cow-pasture-death</metric>
    <metric>cow-edge-death</metric>
    <metric>cow-interior-death</metric>
    <enumeratedValueSet variable="patch-availability">
      <value value="75"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-wolves">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-elk">
      <value value="480"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herd-size">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-farms">
      <value value="9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fear?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cattle-treatment">
      <value value="&quot;cattle-herded&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-fragments">
      <value value="9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pack-elasticity">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herd-elasticity">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolf-fear?">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="HighAvail_HighConnect_CPasture" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="365"/>
    <metric>count elk</metric>
    <metric>count cows</metric>
    <metric>elk-death</metric>
    <metric>elk-forest-death</metric>
    <metric>elk-pasture-death</metric>
    <metric>elk-edge-death</metric>
    <metric>elk-interior-death</metric>
    <metric>cow-death</metric>
    <metric>cow-forest-death</metric>
    <metric>cow-pasture-death</metric>
    <metric>cow-edge-death</metric>
    <metric>cow-interior-death</metric>
    <enumeratedValueSet variable="patch-availability">
      <value value="75"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-wolves">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-elk">
      <value value="480"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herd-size">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-farms">
      <value value="9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fear?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cattle-treatment">
      <value value="&quot;cattle-pasture&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-fragments">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pack-elasticity">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herd-elasticity">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolf-fear?">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="HighAvail_HighConnect_CHerded" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="365"/>
    <metric>count elk</metric>
    <metric>count cows</metric>
    <metric>elk-death</metric>
    <metric>elk-forest-death</metric>
    <metric>elk-pasture-death</metric>
    <metric>elk-edge-death</metric>
    <metric>elk-interior-death</metric>
    <metric>cow-death</metric>
    <metric>cow-forest-death</metric>
    <metric>cow-pasture-death</metric>
    <metric>cow-edge-death</metric>
    <metric>cow-interior-death</metric>
    <enumeratedValueSet variable="patch-availability">
      <value value="75"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-wolves">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-elk">
      <value value="480"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herd-size">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-farms">
      <value value="9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fear?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cattle-treatment">
      <value value="&quot;cattle-herded&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-fragments">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pack-elasticity">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herd-elasticity">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolf-fear?">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="LowAvail_HighConnect_CPasture" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="365"/>
    <metric>count elk</metric>
    <metric>count cows</metric>
    <metric>elk-death</metric>
    <metric>elk-forest-death</metric>
    <metric>elk-pasture-death</metric>
    <metric>elk-edge-death</metric>
    <metric>elk-interior-death</metric>
    <metric>cow-death</metric>
    <metric>cow-forest-death</metric>
    <metric>cow-pasture-death</metric>
    <metric>cow-edge-death</metric>
    <metric>cow-interior-death</metric>
    <enumeratedValueSet variable="patch-availability">
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-wolves">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-elk">
      <value value="480"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herd-size">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-farms">
      <value value="9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fear?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cattle-treatment">
      <value value="&quot;cattle-pasture&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-fragments">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pack-elasticity">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herd-elasticity">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolf-fear?">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="LowAvail_HighConnect_CHerded" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="365"/>
    <metric>count elk</metric>
    <metric>count cows</metric>
    <metric>elk-death</metric>
    <metric>elk-forest-death</metric>
    <metric>elk-pasture-death</metric>
    <metric>elk-edge-death</metric>
    <metric>elk-interior-death</metric>
    <metric>cow-death</metric>
    <metric>cow-forest-death</metric>
    <metric>cow-pasture-death</metric>
    <metric>cow-edge-death</metric>
    <metric>cow-interior-death</metric>
    <enumeratedValueSet variable="patch-availability">
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-wolves">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-elk">
      <value value="480"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herd-size">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-farms">
      <value value="9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fear?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cattle-treatment">
      <value value="&quot;cattle-herded&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-fragments">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pack-elasticity">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herd-elasticity">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolf-fear?">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MedAvail_HighConnect_CPasture" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="365"/>
    <metric>count elk</metric>
    <metric>count cows</metric>
    <metric>elk-death</metric>
    <metric>elk-forest-death</metric>
    <metric>elk-pasture-death</metric>
    <metric>elk-edge-death</metric>
    <metric>elk-interior-death</metric>
    <metric>cow-death</metric>
    <metric>cow-forest-death</metric>
    <metric>cow-pasture-death</metric>
    <metric>cow-edge-death</metric>
    <metric>cow-interior-death</metric>
    <enumeratedValueSet variable="patch-availability">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-wolves">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-elk">
      <value value="480"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herd-size">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-farms">
      <value value="9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fear?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cattle-treatment">
      <value value="&quot;cattle-pasture&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-fragments">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pack-elasticity">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herd-elasticity">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolf-fear?">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MedAvail_HighConnect_CHerded" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="365"/>
    <metric>count elk</metric>
    <metric>count cows</metric>
    <metric>elk-death</metric>
    <metric>elk-forest-death</metric>
    <metric>elk-pasture-death</metric>
    <metric>elk-edge-death</metric>
    <metric>elk-interior-death</metric>
    <metric>cow-death</metric>
    <metric>cow-forest-death</metric>
    <metric>cow-pasture-death</metric>
    <metric>cow-edge-death</metric>
    <metric>cow-interior-death</metric>
    <enumeratedValueSet variable="patch-availability">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-wolves">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-elk">
      <value value="480"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herd-size">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-farms">
      <value value="9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fear?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cattle-treatment">
      <value value="&quot;cattle-herded&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-fragments">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pack-elasticity">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herd-elasticity">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolf-fear?">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="LowAvail_MedConnect_CHerded" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="365"/>
    <metric>count elk</metric>
    <metric>count cows</metric>
    <metric>elk-death</metric>
    <metric>elk-forest-death</metric>
    <metric>elk-pasture-death</metric>
    <metric>elk-edge-death</metric>
    <metric>elk-interior-death</metric>
    <metric>cow-death</metric>
    <metric>cow-forest-death</metric>
    <metric>cow-pasture-death</metric>
    <metric>cow-edge-death</metric>
    <metric>cow-interior-death</metric>
    <enumeratedValueSet variable="patch-availability">
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-wolves">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-elk">
      <value value="480"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herd-size">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-farms">
      <value value="9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fear?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cattle-treatment">
      <value value="&quot;cattle-herded&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-fragments">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pack-elasticity">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herd-elasticity">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolf-fear?">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="LowAvail_LowConnect_CHerded" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <postRun>print elk-death
print elk-forest-death
print elk-pasture-death
print elk-edge-death
print elk-interior-death
print cow-death
print cow-forest-death
print cow-pasture-death
print cow-edge-death
print cow-interior-death</postRun>
    <timeLimit steps="365"/>
    <metric>count elk</metric>
    <metric>count cows</metric>
    <metric>elk-death</metric>
    <metric>elk-forest-death</metric>
    <metric>elk-pasture-death</metric>
    <metric>elk-edge-death</metric>
    <metric>elk-interior-death</metric>
    <metric>cow-death</metric>
    <metric>cow-forest-death</metric>
    <metric>cow-pasture-death</metric>
    <metric>cow-edge-death</metric>
    <metric>cow-interior-death</metric>
    <enumeratedValueSet variable="patch-availability">
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-wolves">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-elk">
      <value value="480"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herd-size">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-farms">
      <value value="9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fear?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cattle-treatment">
      <value value="&quot;cattle-herded&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-fragments">
      <value value="9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pack-elasticity">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herd-elasticity">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolf-fear?">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="LowAvail_LowConnect_CEverywhere" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <postRun>print elk-death
print elk-forest-death
print elk-pasture-death
print elk-edge-death
print elk-interior-death
print cow-death
print cow-forest-death
print cow-pasture-death
print cow-edge-death
print cow-interior-death</postRun>
    <timeLimit steps="365"/>
    <metric>count elk</metric>
    <metric>count cows</metric>
    <metric>elk-death</metric>
    <metric>elk-forest-death</metric>
    <metric>elk-pasture-death</metric>
    <metric>elk-edge-death</metric>
    <metric>elk-interior-death</metric>
    <metric>cow-death</metric>
    <metric>cow-forest-death</metric>
    <metric>cow-pasture-death</metric>
    <metric>cow-edge-death</metric>
    <metric>cow-interior-death</metric>
    <enumeratedValueSet variable="patch-availability">
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-wolves">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-elk">
      <value value="480"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herd-size">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-farms">
      <value value="9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fear?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cattle-treatment">
      <value value="&quot;cattle-everywhere&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-fragments">
      <value value="9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pack-elasticity">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herd-elasticity">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolf-fear?">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MedAvail_MedConnect_CPasture" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="365"/>
    <metric>count elk</metric>
    <metric>count cows</metric>
    <metric>elk-death</metric>
    <metric>elk-forest-death</metric>
    <metric>elk-pasture-death</metric>
    <metric>elk-edge-death</metric>
    <metric>elk-interior-death</metric>
    <metric>cow-death</metric>
    <metric>cow-forest-death</metric>
    <metric>cow-pasture-death</metric>
    <metric>cow-edge-death</metric>
    <metric>cow-interior-death</metric>
    <enumeratedValueSet variable="patch-availability">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-wolves">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-elk">
      <value value="480"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herd-size">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-farms">
      <value value="9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fear?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cattle-treatment">
      <value value="&quot;cattle-pasture&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-fragments">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pack-elasticity">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herd-elasticity">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolf-fear?">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MedAvail_MedConnect_CHerded" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="365"/>
    <metric>count elk</metric>
    <metric>count cows</metric>
    <metric>elk-death</metric>
    <metric>elk-forest-death</metric>
    <metric>elk-pasture-death</metric>
    <metric>elk-edge-death</metric>
    <metric>elk-interior-death</metric>
    <metric>cow-death</metric>
    <metric>cow-forest-death</metric>
    <metric>cow-pasture-death</metric>
    <metric>cow-edge-death</metric>
    <metric>cow-interior-death</metric>
    <enumeratedValueSet variable="patch-availability">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-wolves">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-elk">
      <value value="480"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herd-size">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-farms">
      <value value="9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fear?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cattle-treatment">
      <value value="&quot;cattle-herded&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-fragments">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pack-elasticity">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herd-elasticity">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolf-fear?">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MedAvail_LowConnect_CPasture" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="365"/>
    <metric>count elk</metric>
    <metric>count cows</metric>
    <metric>elk-death</metric>
    <metric>elk-forest-death</metric>
    <metric>elk-pasture-death</metric>
    <metric>elk-edge-death</metric>
    <metric>elk-interior-death</metric>
    <metric>cow-death</metric>
    <metric>cow-forest-death</metric>
    <metric>cow-pasture-death</metric>
    <metric>cow-edge-death</metric>
    <metric>cow-interior-death</metric>
    <enumeratedValueSet variable="patch-availability">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-wolves">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-elk">
      <value value="480"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herd-size">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-farms">
      <value value="9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fear?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cattle-treatment">
      <value value="&quot;cattle-pasture&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-fragments">
      <value value="9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pack-elasticity">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herd-elasticity">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolf-fear?">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MedAvail_LowConnect_CHerded" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="365"/>
    <metric>count elk</metric>
    <metric>count cows</metric>
    <metric>elk-death</metric>
    <metric>elk-forest-death</metric>
    <metric>elk-pasture-death</metric>
    <metric>elk-edge-death</metric>
    <metric>elk-interior-death</metric>
    <metric>cow-death</metric>
    <metric>cow-forest-death</metric>
    <metric>cow-pasture-death</metric>
    <metric>cow-edge-death</metric>
    <metric>cow-interior-death</metric>
    <enumeratedValueSet variable="patch-availability">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-wolves">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-elk">
      <value value="480"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herd-size">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-farms">
      <value value="9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fear?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cattle-treatment">
      <value value="&quot;cattle-herded&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-fragments">
      <value value="9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pack-elasticity">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herd-elasticity">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolf-fear?">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="LowAvail_MedConnect_CPasture" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="365"/>
    <metric>count elk</metric>
    <metric>count cows</metric>
    <metric>elk-death</metric>
    <metric>elk-forest-death</metric>
    <metric>elk-pasture-death</metric>
    <metric>elk-edge-death</metric>
    <metric>elk-interior-death</metric>
    <metric>cow-death</metric>
    <metric>cow-forest-death</metric>
    <metric>cow-pasture-death</metric>
    <metric>cow-edge-death</metric>
    <metric>cow-interior-death</metric>
    <enumeratedValueSet variable="patch-availability">
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-wolves">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-elk">
      <value value="480"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herd-size">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-farms">
      <value value="9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fear?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cattle-treatment">
      <value value="&quot;cattle-pasture&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-fragments">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pack-elasticity">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herd-elasticity">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolf-fear?">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
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
