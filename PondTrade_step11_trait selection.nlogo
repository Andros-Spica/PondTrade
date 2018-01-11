;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; GNU GENERAL PUBLIC LICENSE ;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;  The PondTrade model
;;  Copyright (C) 2018 Andreas Angourakis (andros.spica@gmail.com)
;;
;;  This program is free software: you can redistribute it and/or modify
;;  it under the terms of the GNU General Public License as published by
;;  the Free Software Foundation, either version 3 of the License, or
;;  (at your option) any later version.
;;
;;  This program is distributed in the hope that it will be useful,
;;  but WITHOUT ANY WARRANTY; without even the implied warranty of
;;  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;  GNU General Public License for more details.
;;
;;  You should have received a copy of the GNU General Public License
;;  along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;;;;;;;;;;;;;;;;
;;; BREEDS ;;;;;;
;;;;;;;;;;;;;;;;;

breed [ settlements settlement ]
breed [ ships ship ]

;;;;;;;;;;;;;;;;;
;;; VARIABLES ;;;
;;;;;;;;;;;;;;;;;

globals [ routes ]

settlements-own
[
  sizeLevel
  currentNumberOfShips potentialNumberOfShips
  stock
  culturalVector
]

ships-own
[
  isActivated
  base route destination direction lastPosition
  cargoValue
  culturalSample
]

patches-own
[
  isLand
  pathCost

  ;;; path-finding related
  parent-patch ; patch's predecessor
  f ; the value of knowledge plus heuristic cost function f()
  g ; the value of knowledge cost function g()
  h ; the value of heuristic cost function h()
]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; SETUP ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to setup

  clear-all
  reset-ticks

  create-map

  create-coastal-settlements

  set-routes

  create-ships-per-settlement

  update-display

  update-plots

end

to create-map

  let centralPatch patch (min-pxcor + (floor world-width / 2)) (min-pycor + (floor world-height / 2))

  let halfSmallerDimension (world-width / 2)
  if (world-width > world-height) [ set halfSmallerDimension (world-height / 2) ]

  let minDistOfLandToCenter round ((pondSize / 100) * halfSmallerDimension)

  ask patches
  [

    let coastThreshold minDistOfLandToCenter ; defaults to the basic value

    ;; add noise to coast line
    ; set general noise range depending on UI's coastalNoiseLevel and the size of world
    let noiseRange (halfSmallerDimension * coastalNoiseLevel / 100)

    ; noiseType is specified with the chooser in the UI
    if (noiseType = "uniform")
    [
      ; adds a random amount from a uniform distribution with mean minDistOfLandToCenter
      set noiseRange (random-float noiseRange) - (noiseRange / 2)
      set coastThreshold minDistOfLandToCenter + noiseRange
    ]
    if (noiseType = "normal")
    [
      ; adds a random amount from a normal distribution with mean minDistOfLandToCenter
      set coastThreshold random-normal minDistOfLandToCenter (halfSmallerDimension * coastalNoiseLevel / 100)
    ]

    ifelse (distance centralPatch < coastThreshold)
    [
      set isLand false
    ]
    [
      set isLand true
    ]
  ]

  smooth-coast-line

  assign-path-cost

  ask patches [ paint-terrain ]

end

to smooth-coast-line

  ; smooth coast line
  repeat smoothIterations
  [
    ask patches
    [
      ifelse (isLand = false)
      [
        ; water patch
        ; consider ratios instead of absolute numbers to avoid having isolated water bodies adjacent to the world limits (less than 8 neighbors)
        if (count neighbors with [isLand = true] / count neighbors >= coastLineSmoothThreshold / 8)
        [
          ; water patch has a certain number of land neighbors
          set isLand true ; converted to land
        ]
      ]
      [
        ; land patch
        if (count neighbors with [isLand = false] / count neighbors >= coastLineSmoothThreshold / 8)
        [
          ; land patch has a certain number of water neighbors
          set isLand false ; converted to water
        ]
      ]
    ]
  ]

end

to assign-path-cost

  ask patches
  [
    ifelse (isLand = false)
    [ set pathCost 1 ] ; arbitrary unit for now
    [ set pathCost relativePathCostInLand ] ; defined by parameter in relation to the cost of path in water (i.e., 1)
  ]

end

to paint-terrain ; ego = patch

  ifelse (isLand = false)
  [ set pcolor 104 ] ; blue for water
  [ set pcolor 55 ] ; green for land

end

to create-coastal-settlements

  ; consider only coastal patches
  let coastalPatches patches with [(isLand = true) and (any? neighbors with [isLand = false])]

  repeat numberOfSettlements
  [
    ; ask a random coastal patch without a settlement already
    ask one-of coastalPatches with [not any? settlements-here]
    [
      sprout-settlements 1 ; creates one "turtle" of breed settlements
      [
        set sizeLevel 1 ; the size level is initiated at minimum (i.e., 1)
        set stock 0

        set culturalVector extract-rgb color ; 0#, 1# and 2#
        ; We add seven continuos cultural traits to the neutral RGB traits,
        ; representing their attitude and ability involving
        ; aspects we previously fixed as parameters and one variable:
        ; 3# relativePathCostInLand (normal distribution around global parameter)
        set culturalVector lput (random-normal 0 landTechVariation) culturalVector
        ; 4# relativePathCostInPort (normal distribution around global parameter)
        set culturalVector lput (random-normal 0 portTechVariation) culturalVector
        ; 5# settlementSizeDecayRate [0 - maxSettlementSizeDecayRate)
        set culturalVector lput (random-float maxSettlementSizeDecayRate) culturalVector
        ; 6# stockDecayRate [0 - maxStockDecayRate)
        set culturalVector lput (random-float maxStockDecayRate) culturalVector
        ; 7# produtionRate [0 - maxProductionRate)
        set culturalVector lput (random-float maxProductionRate) culturalVector
        ; 8# frequencyOverQuality [0 - 1)
        set culturalVector lput (random-float 1) culturalVector
        ; 9# traitTransmissionRate [0 - maxTraitTransmissionRate) *** now, it means specifically the 'openess' of a settlement towards other variants of a trait
        set culturalVector lput (random-float maxTraitTransmissionRate) culturalVector
        ; 10# mutationVariation [0 - maxMutationVariation)
        set culturalVector lput (random-float maxMutationVariation) culturalVector

        set shape "circle 2"
      ]
      ; replace the land path cost with the port pathCost
      set pathCost relativePathCostInPort
      ; exclude this patch from the pool of coastal patches
      set coastalPatches other coastalPatches
    ]
  ]

end

to create-ships-per-settlement

  ask settlements
  [
    let thisSettlement self ; to avoid the confusion of nested agent queries

    set potentialNumberOfShips get-potential-number-of-ships

    hatch-ships potentialNumberOfShips ; use the sizeLevel variable as the number of ships based in the settlement
    [
      setup-ship thisSettlement
    ]

    set currentNumberOfShips get-current-number-of-ships
  ]

end

to setup-ship [ baseSettlement ]

  set base baseSettlement
  set isActivated true

  ; give meaningful display related to base
  set shape "sailboat side" ; import this shape from the library (Tools > Shape editor > import from library)
  set color [color] of base
  set size 3

  choose-destination

end

to set-routes

  set routes [] ; initialize/reset the routes as an empty list

  let settlementsWithoutRoutes settlements ; helper variable to keep track of which settlement already searched for routes

  ask settlements
  [
    let thisSettlement self

    ask other settlementsWithoutRoutes
    [
      let optimalRoute find-a-path ([patch-here] of thisSettlement) ([patch-here] of self) ; find the optimal route to this settlement
      set routes lput optimalRoute routes ; add the optimal route to the end of the routes list
    ]

    set settlementsWithoutRoutes other settlementsWithoutRoutes

  ]

end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; CYCLE ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to go

  tick

  if (ticks = 10000 or count turtles > 500) [ stop ]

  update-ships

  update-settlements

  update-display

end

to update-ships

  let activeShips ships with [isActivated]
  let shipsInBase activeShips with [is-in-base]
  let shipsInDestination activeShips with [is-in-destination]

  ; UPDATE LAST POSITION
  ask activeShips
  [
    ; update lastPosition if in a patch centre
    if ((xcor = [pxcor] of patch-here) and (ycor = [pycor] of patch-here))
    [
      set lastPosition patch-here
    ]
  ]

  ; UNLOAD
  ask (turtle-set shipsInBase shipsInDestination) with [cargoValue > 0]
  [
    ; unload cargo (changes sizeLevel)
    unload-cargo
  ]

  ; CHECK if the ship can be sustained when in the base
  ask shipsInBase
  [
    if ([potentialNumberOfShips < currentNumberOfShips] of base)
    [
      ; the current number of ships cannot be sustained
      set isActivated false
      ; update currentNumberOfShips of base
      ask base [ set currentNumberOfShips get-current-number-of-ships ]
    ]
  ]

  set activeShips ships with [isActivated] ; update active ships
  set shipsInBase shipsInBase with [isActivated] ; update ships in base

  ; LOAD
  ask (turtle-set shipsInBase shipsInDestination)
  [
    ; load cargo (changes stock)
    load-cargo
  ]

  ; CHOOSE DESTINATION
  ask shipsInBase with [cargoValue > 0]
  [
    ; update the destination whenever in the base settlement and there is cargo to transport
    choose-destination
  ]

  ; FIND DIRECTION in route
  ask (turtle-set shipsInBase shipsInDestination)
  [
    find-direction
  ]

  ; MOVE towards the next position in the route
  ask activeShips with [cargoValue > 0]
  [
    ; move following the route when there is cargo to transport
    move-to-destination
  ]

end

to choose-destination ; ego = ship

  let thisShip self

  ; get routes connecting the base settlement
  let routesFromBase get-routes-to-settlement [base] of thisShip

  ; order these routes by benefit/cost ratio
  set routesFromBase sort-by [ benefit-cost-of-route ?1 thisShip > benefit-cost-of-route ?2 thisShip ] routesFromBase

  ; print the options available
;  foreach routesFromBase
;  [
;    print "==============================================================="
;    print "route between:"
;    print [who] of get-origin-and-destination ?
;    print "has the benefit-cost ratio of:"
;    print benefit-cost-of-route ?
;  ]
;  print "-x-x-x-x-x-x-x-x-x-x-x-x-x-x-x-x-x-x-x-x-x-x"

  ; select the one with higher benefit/cost ratio
  set route first routesFromBase

  ; get the settlement of destination
  set destination one-of (get-origin-and-destination route) with [who != [who] of ([base] of thisShip)]

end

to find-direction ; ego = ship

  ; find where in the route list is the ship
  let currentPosition position lastPosition route

  ; set direction if in a settlement
  ifelse (currentPosition = 0) ; in the first extreme of the route list
  [
    ; move in the route list towards larger index numbers
    set direction 1
  ]
  [
    if (currentPosition = (length route - 1)) ; in the last extreme of the route list
    [
      ; move in the route list towards smaller index numbers
      set direction -1
    ]
  ]
  ; else the ship is in route to either the base or the destination

end

to move-to-destination ; ego = ship

  ; find where in the route list is the ship
  let currentPosition position lastPosition route

  ; move through the route following direction
  let targetPatch item (currentPosition + direction) route
  ;move-to targetPatch ; constant travel time (1 patch per tick)
  facexy ([pxcor] of targetPatch) ([pycor] of targetPatch)

  forward min (
    list
    (1 / get-path-cost patch-here self) ; the maximum distance in a tick in the current patch
    (distancexy ([pxcor] of targetPatch) ([pycor] of targetPatch)) ; the distance to the target patch
    )

end

to-report is-in-base ; ego = ship

  report (xcor = [xcor] of base) and (ycor = [ycor] of base) ; if the ship arrived at the centre of the base patch

end

to-report is-in-destination ; ego = ship

  report (xcor = [xcor] of destination) and (ycor = [ycor] of destination) ; if the ship arrived at the centre of the destination patch

end

to unload-cargo ; ego = ship

  let thisShip self
  let settlementHere one-of settlements-here

  ; unload cargo
  ask settlementHere [ add-trade-effect thisShip ]

end

to load-cargo ; ego = ship

  let settlementHere one-of settlements-here

  ; load cargo
  set cargoValue [stock] of settlementHere
  ask settlementHere [ set stock 0 ] ; empty the settlement stock

  set culturalSample [culturalVector] of settlementHere

end

to update-settlements

  ask settlements
  [
    let thisSettlement self

    ; the sizeLevel of settlements decays with a constant rate, up to 1 (minimum)
    set sizeLevel max (list 1 (sizeLevel * (1 - ((item 5 culturalVector) / 100)) ) )
    ; production in stock also decays with a constant rate
    set stock stock * (1 - ((item 6 culturalVector) / 100))
    ; prodution is generated in proportion to sizeLevel, following a constant rate
    set stock stock + sizeLevel * ((item 7 culturalVector) / 100)

    ; determine the current and potential number of ships
    set currentNumberOfShips get-current-number-of-ships
    set potentialNumberOfShips get-potential-number-of-ships

    ; conditions favors the creation of new ships
    if (random-float 1 > currentNumberOfShips / potentialNumberOfShips )
    [
      ; create a new ship or activate an old one
      repeat 1
      [
        ifelse (any? ships with [not isActivated])
        [
          ask one-of ships with [not isActivated]
          [
            setup-ship thisSettlement
            move-to thisSettlement
          ]
        ]
        [
          hatch-ships 1
          [
            setup-ship thisSettlement
          ]
        ]
      ]
      set currentNumberOfShips get-current-number-of-ships ; update currentNumberOfShips
    ]

    ; add variation to the settlement traits (mutation)
    mutate-traits
  ]

end

to add-trade-effect [ aShip ] ; ego = settlement

  ; cultural transmission ship to port
  let newCulturalVector []
  foreach culturalVector
  [
    let otherSettlementTrait item (length newCulturalVector) [culturalSample] of aShip
    let traitChange (otherSettlementTrait - ?) * ((item 9 culturalVector) / 100)
    set newCulturalVector lput (? + traitChange) newCulturalVector
  ]
;  print (word "========== " self " ============")
;  print (word "old vector: " culturalVector ", new vector: " newCulturalVector)
  set culturalVector newCulturalVector

  set sizeLevel sizeLevel + [cargoValue] of aShip

end

to mutate-traits

  let mutationVariationToApply (item 10 culturalVector) / 100
  ;print "========================================"
  ;print culturalVector
  ; #1, #2 and #3
  set culturalVector replace-item 0 culturalVector mutate-trait (item 0 culturalVector) 0 255 mutationVariationToApply
  set culturalVector replace-item 1 culturalVector mutate-trait (item 1 culturalVector) 0 255 mutationVariationToApply
  set culturalVector replace-item 2 culturalVector mutate-trait (item 2 culturalVector) 0 255 mutationVariationToApply

  ; #3 and #4 (relativePathCostInLand, relativePathCostInPort)
  set culturalVector replace-item 3 culturalVector mutate-trait (item 3 culturalVector) (-1 * relativePathCostInLand + 1) 100 mutationVariationToApply ; arbitrary maximum
  set culturalVector replace-item 4 culturalVector mutate-trait (item 4 culturalVector) (-1 * relativePathCostInPort + 1) 100 mutationVariationToApply ; arbitrary maximum

  ; #5, #6 and #6 (settlementSizeDecayRate, stockDecayRate, produtionRate)
  set culturalVector replace-item 5 culturalVector mutate-trait (item 5 culturalVector) 0 maxSettlementSizeDecayRate mutationVariationToApply
  set culturalVector replace-item 6 culturalVector mutate-trait (item 6 culturalVector) 0 maxStockDecayRate mutationVariationToApply
  set culturalVector replace-item 7 culturalVector mutate-trait (item 7 culturalVector) 0 maxProductionRate mutationVariationToApply

  ; #8, #9 and #10 (frequencyOverQuality, traitTransmissionRate, mutationVariation)
  set culturalVector replace-item 8 culturalVector mutate-trait (item 8 culturalVector) 0 1 mutationVariationToApply
  set culturalVector replace-item 9 culturalVector mutate-trait (item 9 culturalVector) 0 maxTraitTransmissionRate mutationVariationToApply
  set culturalVector replace-item 10 culturalVector mutate-trait (item 10 culturalVector) 0 maxMutationVariation mutationVariationToApply

  ;print culturalVector

end

to-report mutate-trait [ traitValue minValue maxValue mutationVar ]

  report (max (list minValue min (list maxValue (traitValue + (random-normal 0 mutationVar) * (maxValue - minValue)))))

end


to-report get-potential-number-of-ships ; ego = settlement

  report (
    1 +
    (sizeLevel - 1) * (item 8 culturalVector)
    )

end

to-report get-current-number-of-ships ; ego = settlement

  let thisSettlement self
  report count ships with [isActivated and base = thisSettlement ]

end

to update-display

  paint-routes
  paint-active-routes

  ; scale the size of settlements according to their dynamic free-scaled sizeLevel
  let maxSettlementSize max [sizeLevel] of settlements

  ask settlements
  [
    set hidden? not showSettlements
    set size 1 + (sizeLevel / maxSettlementSize) * 9
    set color rgb (item 0 culturalVector) (item 1 culturalVector) (item 2 culturalVector)
  ]

  ask ships
  [
    ifelse (isActivated)
    [ set hidden? false ]
    [ set hidden? true ]
  ]

end

to paint-routes

  ; resets route patches to the terrain color
  foreach routes
  [
    let aRoute ?

    foreach aRoute
    [
      ask ? [ paint-terrain ]
    ]
  ]

  ; paint route patches in shades of red depending on route frequency
  foreach routes
  [
    let aRoute ?

    foreach aRoute
    [
      ask ?
      [
        if (showRoutes)
        [
          ifelse (pcolor < 11 or pcolor > 19) ; if its the first route crossing the patch
          [
            set pcolor 11
          ]
          [
            set pcolor min (list (pcolor + 1) (19)) ; sets a maximum at 19 (the brightest)
          ]
        ]
      ]
    ]
  ]

end

to paint-active-routes

  ask ships
  [
    foreach route
    [
      ask ?
      [
        ifelse (showActiveRoutes)
        [
          set pcolor yellow
        ]
        [
          if (not showRoutes) ; if not displaying all routes
          [
            ; resets to the patch terrain color
            paint-terrain
          ]
        ]
      ]
    ]
  ]

end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Get and set routes (helper 'to-report' procedures) ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to-report get-route [ settlement1 settlement2 ] ; accepts two settlements and returns a route

  ; get routes connecting settlement1
  let routesFromSettlement1 filter
  [
    ([one-of settlements-here] of first ? = settlement1) or
    ([one-of settlements-here] of last ? = settlement1)
  ] routes

  ; get the route connecting settlement2 from the previous list
  let routeFromSettlement1ToSettlement2 filter
  [
    ([one-of settlements-here] of first ? = settlement2) or
    ([one-of settlements-here] of last ? = settlement2)
  ] routesFromSettlement1

  report first routeFromSettlement1ToSettlement2

end

to-report get-routes-to-settlement [ aSettlement ] ; accepts a settlement and return a list of routes

  report filter
  [
    ([one-of settlements-here] of first ? = aSettlement) or
    ([one-of settlements-here] of last ? = aSettlement)
  ] routes

end

to-report get-origin-and-destination [ aRoute ] ; accepts a route and returns a turtle-set with two settlements

  report (turtle-set ([ one-of settlements-here ] of first aRoute) ([one-of settlements-here ] of last aRoute))

end

to-report benefit-cost-of-route [ aRoute aShip ] ; accepts a route andpan returns a number (the benefit/cost ratio of the route)

  let cost 0

  foreach aRoute ; for every patch in the given route
  [
    set cost cost + get-path-cost ? aShip
  ]

  let originAndDestination get-origin-and-destination aRoute
  let benefit 0
  ask originAndDestination [ set benefit benefit + sizeLevel ] ; the benefit is the sum of the sizeLevel of the two settlements

  report benefit / cost

end

to-report get-path-cost [ aPatch aShip ]

  let pathCostOfPatch [pathCost] of aPatch
  if ([isLand] of aPatch)
  [
    ifelse ([any? settlements-here] of aPatch)
    [
      ; path cost in port apply
      set pathCostOfPatch pathCostOfPatch + [(item 4 culturalVector)] of [base] of aShip
    ]
    [
      ; path cost in land apply
      set pathCostOfPatch pathCostOfPatch + [(item 3 culturalVector)] of [base] of aShip
    ]
  ]
  report pathCostOfPatch

end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; A* path finding algorithm ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; modified from Meghendra Singh's Astardemo1 model in NetLogo User Community Models
; http://ccl.northwestern.edu/netlogo/models/community/Astardemo1
; modified lines/fragments are marked with ";-------------------------------*"
; In this version, patches have different movement cost.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; the actual implementation of the A* path finding algorithm
; it takes the source and destination patches as inputs
; and reports the optimal path if one exists between them as output
to-report find-a-path [ source-patch destination-patch]

  ; initialize all variables to default values
  let search-done? false
  let search-path []
  let current-patch 0
  let open [] ;-------------------------------*
  let closed [] ;-------------------------------*

  ;-------------------------------*
  ask patches with [ f != 0 ]
  [
    set f 0
    set h 0
    set g 0
  ]
  ;-------------------------------*

  ; add source patch in the open list
  set open lput source-patch open

  ; loop until we reach the destination or the open list becomes empty
  while [ search-done? != true]
  [
    ifelse length open != 0
    [
      ; sort the patches in open list in increasing order of their f() values
      set open sort-by [[f] of ?1 < [f] of ?2] open

      ; take the first patch in the open list
      ; as the current patch (which is currently being explored (n))
      ; and remove it from the open list
      set current-patch item 0 open
      set open remove-item 0 open

      ; add the current patch to the closed list
      set closed lput current-patch closed

      ; explore the Von Neumann (left, right, top and bottom) neighbors of the current patch
      ask current-patch
      [
        ; if any of the neighbors is the destination stop the search process
        ifelse any? neighbors4 with [ (pxcor = [ pxcor ] of destination-patch) and (pycor = [pycor] of destination-patch)] ;-------------------------------*
        [
          set search-done? true
        ]
        [
          ; the neighbors should not already explored patches (part of the closed list)
          ask neighbors4 with [ (not member? self closed) and (self != parent-patch) ] ;-------------------------------*
          [
            ; the neighbors to be explored should also not be the source or
            ; destination patches or already a part of the open list (unexplored patches list)
            if not member? self open and self != source-patch and self != destination-patch
            [
              ;set pcolor 45 ;-------------------------------*

              ; add the eligible patch to the open list
              set open lput self open

              ; update the path finding variables of the eligible patch
              set parent-patch current-patch
              set g [g] of parent-patch + pathCost ;-------------------------------*
              set h distance destination-patch
              set f (g + h)
            ]
          ]
        ]
;        if self != source-patch ;-------------------------------*
;        [
;          set pcolor 35
;        ]
      ]
    ]
    [
      ; if a path is not found (search is incomplete) and the open list is exhausted
      ; display a user message and report an empty search path list.
      user-message( "A path from the source to the destination does not exist." )
      report []
    ]
  ]

  ; if a path is found (search completed) add the current patch
  ; (node adjacent to the destination) to the search path.
  set search-path lput current-patch search-path

  ; trace the search path from the current patch
  ; all the way to the source patch using the parent patch
  ; variable which was set during the search for every patch that was explored
  let temp first search-path
  while [ temp != source-patch ]
  [
;    ask temp ;-------------------------------*
;    [
;      set pcolor 85
;    ]
    set search-path lput [parent-patch] of temp search-path
    set temp [parent-patch] of temp
  ]

  ; add the destination patch to the front of the search path
  set search-path fput destination-patch search-path

  ; reverse the search path so that it starts from a patch adjacent to the
  ; source patch and ends at the destination patch
  set search-path reverse search-path

  ; report the search path
  report search-path
end
@#$#@#$#@
GRAPHICS-WINDOW
292
16
790
535
30
30
8.0
1
10
1
1
1
0
0
0
1
-30
30
-30
30
0
0
1
ticks
30.0

SLIDER
10
497
245
530
pondSize
pondSize
0
100
75
1
1
% of smallest dimension
HORIZONTAL

SLIDER
10
577
250
610
coastalNoiseLevel
coastalNoiseLevel
0
100
20
1
1
% of minDistToCentre
HORIZONTAL

SLIDER
10
612
276
645
coastLineSmoothThreshold
coastLineSmoothThreshold
0
8
5
1
1
of 8 neighbors
HORIZONTAL

CHOOSER
10
531
148
576
noiseType
noiseType
"no noise" "uniform" "normal"
2

SLIDER
10
646
182
679
smoothIterations
smoothIterations
0
20
3
1
1
NIL
HORIZONTAL

SLIDER
57
53
229
86
numberOfSettlements
numberOfSettlements
0
50
30
1
1
NIL
HORIZONTAL

BUTTON
11
15
78
48
Set up
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

SWITCH
13
399
143
432
showSettlements
showSettlements
0
1
-1000

BUTTON
157
387
251
420
Update display
update-display
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

TEXTBOX
11
476
161
494
Map parameters
14
0.0
1

SLIDER
4
93
280
126
relativePathCostInLand
relativePathCostInLand
1
100
50
0.01
1
X path cost in water
HORIZONTAL

BUTTON
96
16
159
49
Go
go
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
180
16
243
49
Go
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

TEXTBOX
15
377
165
395
Display options
14
0.0
1

SWITCH
13
432
120
465
showRoutes
showRoutes
1
1
-1000

SLIDER
6
201
278
234
maxSettlementSizeDecayRate
maxSettlementSizeDecayRate
0
25
20
0.01
1
% of sizeLevel
HORIZONTAL

SWITCH
120
432
260
465
showActiveRoutes
showActiveRoutes
0
1
-1000

PLOT
810
382
1281
502
Settlement size distribution
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"carefully [set-plot-x-range -0.1 ((max [sizeLevel] of settlements) + 0.1)] [ set-plot-x-range 0 1 ]\nset-histogram-num-bars 20" "carefully [set-plot-x-range -0.1 ((max [sizeLevel] of settlements) + 0.1)] [ set-plot-x-range 0 1 ]\nset-histogram-num-bars 20"
PENS
"default" 1.0 1 -16777216 true "histogram [sizeLevel] of settlements" "histogram [sizeLevel] of settlements"

PLOT
812
503
1282
623
Main hub settlement
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 2 -16777216 true "" "let hub max-one-of settlements [sizeLevel]\ncarefully [ set-plot-pen-color approximate-rgb (item 0 ([color] of hub)) (item 1 ([color] of hub)) (item 2 ([color] of hub))] []\ncarefully [ plot [who] of hub] [ plot 0 ]"

SLIDER
6
301
284
334
maxTraitTransmissionRate
maxTraitTransmissionRate
0
25
20
0.01
1
% of trait difference
HORIZONTAL

PLOT
810
17
1069
137
Neutral traits
variants
frequency
0.0
10.0
0.0
10.0
true
true
"set-plot-x-range -1 256" "set-plot-x-range -1 256"
PENS
"trait 1#" 1.0 1 -2674135 true "set-histogram-num-bars 33\nhistogram [item 0 culturalVector] of settlements" "histogram [item 0 culturalVector] of settlements"
"trait 2#" 1.0 1 -10899396 true "set-histogram-num-bars 25\nhistogram [item 1 culturalVector] of settlements" "histogram [item 1 culturalVector] of settlements"
"trait 3#" 1.0 1 -13345367 true "set-histogram-num-bars 20\nhistogram [item 1 culturalVector] of settlements" "histogram [item 2 culturalVector] of settlements"

SLIDER
4
127
280
160
relativePathCostInPort
relativePathCostInPort
1
100
10
0.01
1
X path cost in water
HORIZONTAL

SLIDER
6
234
277
267
maxStockDecayRate
maxStockDecayRate
0
25
20
0.01
1
% of stock
HORIZONTAL

SLIDER
6
267
277
300
maxProductionRate
maxProductionRate
0
25
15
0.01
1
% of sizeLevel
HORIZONTAL

PLOT
810
260
1282
380
Ships
ticks
count
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot count ships with [isActivated]"

SLIDER
5
162
143
195
landTechVariation
landTechVariation
0
20
5
0.01
1
NIL
HORIZONTAL

SLIDER
143
162
280
195
portTechVariation
portTechVariation
0
20
5
0.01
1
NIL
HORIZONTAL

PLOT
1069
138
1331
258
Settlement economy traits
variant
frequency
0.0
10.0
0.0
10.0
true
true
"set-plot-x-range -0.1 1.1" "set-plot-x-range -0.1 1.1"
PENS
"size decay" 1.0 1 -4079321 true "set-histogram-num-bars 33" "histogram [(item 5 culturalVector) / maxSettlementSizeDecayRate] of settlements"
"stock decay" 1.0 1 -15302303 true "set-histogram-num-bars 25" "histogram [(item 6 culturalVector) / maxStockDecayRate] of settlements"
"production" 1.0 1 -5825686 true "set-histogram-num-bars 20" "histogram [(item 7 culturalVector) / maxProductionRate] of settlements"

PLOT
810
138
1069
258
Ship technology (movement cost)
variant
frequency
0.0
10.0
0.0
10.0
true
true
"" "carefully [ set-plot-x-range floor min [min (list item 3 culturalVector item 4 culturalVector)] of settlements - 1 ceiling max [max (list item 3 culturalVector item 4 culturalVector)] of settlements + 1 ] []"
PENS
"land" 1.0 1 -955883 true "set-histogram-num-bars 25" "set-histogram-num-bars 25\nhistogram [item 3 culturalVector] of settlements"
"port" 1.0 1 -13403783 true "set-histogram-num-bars 20" "set-histogram-num-bars 20\nhistogram [item 4 culturalVector] of settlements"

PLOT
1069
17
1331
137
Attitude traits
variant
frequency
0.0
10.0
0.0
10.0
true
true
"set-plot-x-range -0.1 1.1" "set-plot-x-range -0.1 1.1"
PENS
"freq./qual." 1.0 1 -13840069 true "set-histogram-num-bars 33" "histogram [item 8 culturalVector] of settlements"
"transmission" 1.0 1 -7858858 true "set-histogram-num-bars 25" "histogram [(item 9 culturalVector) / maxTraitTransmissionRate] of settlements"
"mutation" 1.0 1 -13791810 true "set-histogram-num-bars 20" "histogram [(item 10 culturalVector) / maxMutationVariation] of settlements"

SLIDER
24
333
261
366
maxMutationVariation
maxMutationVariation
0
5
1
0.01
1
% of trait range
HORIZONTAL

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

sailboat side
false
0
Line -16777216 false 0 240 120 210
Polygon -7500403 true true 0 239 270 254 270 269 240 284 225 299 60 299 15 254
Polygon -1 true false 15 240 30 195 75 120 105 90 105 225
Polygon -1 true false 135 75 165 180 150 240 255 240 285 225 255 150 210 105
Line -16777216 false 105 90 120 60
Line -16777216 false 120 45 120 240
Line -16777216 false 150 240 120 240
Line -16777216 false 135 75 120 60
Polygon -7500403 true true 120 60 75 45 120 30
Polygon -16777216 false false 105 90 75 120 30 195 15 240 105 225
Polygon -16777216 false false 135 75 165 180 150 240 255 240 285 225 255 150 210 105
Polygon -16777216 false false 0 239 60 299 225 299 240 284 270 269 270 254

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
NetLogo 5.3.1
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
