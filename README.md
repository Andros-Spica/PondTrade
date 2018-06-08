# PondTrade
Didactic progressive development of an Agent-based model in NetLogo

This is an Agent-based model (ABM) created explicitly for exemplifying several aspects of the development of ABM models. The target public is students and researchers of Archaeology and History. The development process is broken down into several steps that are progressively complex. Each version introduces a new concept and some NetLogo functionalities.

>NOTE: In the explanation below I'm using `<UPPERCASE_TEXT>` to express the positions in the code to be filled by the name of entities, variables, and other elements, depending on the context. For instance, `<COLOR> <FRUIT>` would represent many possible phrases, such as "red apple", "brown kiwi", etc. 

## Hello World!

The code illustrates a single "procedure", called `create-map`, enclosed within a structure of the type:
```NetLogo
to <PROCEDURE NAME>
  <PROCEDURE_ACTION_1>
  <PROCEDURE_ACTION_2>
  <PROCEDURE_ACTION_3>
  ...
end
```
Any procedure can be executed by typing `<PROCEDURE_NAME>+Enter` in the NetLogo's console at the bottom of the 'Interface' tab. In this case, the procedure `hello-world`:
```NetLogo
to hello-world
  print "Hello World!"
end
```
would generate the following "prints" in the console:
```
observer> hello-world
Hello World!
```
NetLogo's interface editor allows us to create buttons that can execute one or multiple procedures (or even a snippet of *ad hoc* code). For any doubts on how to edit the interface tab, please refer to NetLogo's documentation (https://ccl.northwestern.edu/netlogo/docs/interfacetab.html).

## NetLogo's entities

The first thing one should learn about NetLogo (and most agent-based modeling system) is that it handles *mainly* two types of entities/agents: `patches`, cells in a square grid, and `turtles`, which are proper "agents" (i.e., able to move). Both entities posses *primitives* (built-in, default properties), some of which can be modified by processes in your model. For example, you can't modify the position of a patch, but you can change its filling color. See NetLogo's documentation on agents for further details (https://ccl.northwestern.edu/netlogo/docs/programming.html#agents).

One should spend some time understanding the grid structure and associated syntaxis. It is recommendable to consult the "settings" pop-up window in the "interface tab":

![](https://ccl.northwestern.edu/netlogo/docs/images/interfacetab/settings.gif)

The default configuration is a 33x33 grid with the position (0,0) at the center. Both dimensions and center can be easily edited for each particular model. Moreover, we can specify agents behavior at the borders by ticking the "wrap" options. Wrapping the world limits means that, for instance, under the default setting mentioned above, the position (-16,0) is adjacent to (16,0). In the console, we can "ask" the patch at (-16,0) to print its distance to the patch at (16,0), using the primitive function `distance` (https://ccl.northwestern.edu/netlogo/docs/dictionary.html#distance):
```
observador> ask patch -16 0 [ print distance patch 16 0 ]
1
```
Wrapping one dimension represents a cylindrical surface while wrapping two depicts a strange toroidal object (Donut!). Although this aspect is relatively hidden among the options, it can have great importance if spatial relations play any part in a model. So if you want your grid to represent a geographical map, make sure to untick the wrapping features.

## Step 0: Drawing a blue circle

This is the actual initial step in building the **Pond Trade** model. It introduces the student to several fundamental concepts of NetLogo's programming language.

Inside a single procedure, called `create-map`, the code illustrates how all entities of a type (`patches`) can be ordered (`ask`) to do something using the structure: 
```
ask <ENTITIES>
[ 
  <DO_SOMETHING>
]
```
The code also introduces the syntaxis to set the values of variables, i.e. `set <VARIABLE> <VALUE>` (in this case, to change color):
```NetLogo
set pcolor blue
```
and to declare and set local variables (i.e., accessable only from its own context) by using `let <VARIABLE> <VALUE>`. In this case, for instance, we use a local variable to identify the patch at the postion (0,0) as the one at the center:
```NetLogo
let centralPatch patch 0 0
``` 
Furthermore, we show how to "comment" (i.e., write text that should be ignored when executing the code) using the structure:
```NetLogo
; <FREE_TEXT>
```
or
```NetLogo
<CODE> ; <FREE_TEXT>
```
The code exemplifies how to create conditional rules according to predefined general conditions using if/else statements, which in NetLogo can be written as `if` or `ifelse`:
```NetLogo
if (<CONDITION_1_IS_TRUE>)
[
  <DO_ACTION_A>
]

ifelse (<CONDITION_2_IS_TRUE>)
[
  <DO_ACTION_B>
]
[
  <DO_ACTION_C>
]
```
In this step, we are ordering patches to paint themselves green or blue depending on if their distance to the center is less than a given value).
```NetLogo
ifelse (distance centralPatch < minDistOfLandToCentre)
[
  set pcolor blue ; water
]
[
  set pcolor green ; land
]
```
To calculate this condition for every patch, we must set up the arbitrary value `minDistOfLandToCentre`, in this case as the rounded half of the grid width
The whole code is kept short so these aspects can be better observed, investigated, and assimilated:
```NetLogo
to create-map

  ask patches [

    ; set central patch
    let centralPatch patch 0 0

    ; set minimum distance to centre depending on world width
    let minDistOfLandToCentre round (0.5 * (world-width / 2))

    ifelse (distance centralPatch < minDistOfLandToCentre)
    [
      set pcolor blue ; water
    ]
    [
      set pcolor green ; land
    ]

  ]

end
 ```

![Step 0 interface in NetLogo](PondTrade_step00_blue-circle-interface.png)

## Step 1: Replacing *magic numbers*

This step exemplifies a very typical situation when designing a model and programming in general. Once you defined a procedure in raw terms and tested that it actually does what you expects, you probably want to generalize it. As the aim of modeling is to represent *a type of* phenomenon, its good practice to have all non-dynamic conditions to be isolated as "parameters", special variables that can be set through user input in the interface tab (e.g., slides, selectors, numeric fields).

In Step 0, the code has several fixed arbitrary values (e.g., the coordinates of the `centralPatch`, the calculation of `minDistOfLandToCentre` assuming half of the world width). It is good enough for us to draw a *particular* blue circle, but it is insufficient to draw other *types of blue circle*. Of course, the code will never be able to draw *anything*, if we are not programming it to do it. We must generalize but also compromise, accepting that there will be possibilities that are not covered by our model. 
