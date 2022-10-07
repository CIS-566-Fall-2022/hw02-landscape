# Project Summary
For my project I decided to make a cartoon stylized seaside. Here's my final product:

https://user-images.githubusercontent.com/25019996/194453796-a77e2acd-0f43-4d9d-8a81-d50634a836fd.mp4
<img width="1505" alt="Screen Shot 2022-10-06 at 9 19 28 PM" src="https://user-images.githubusercontent.com/25019996/194453832-d3d65b6a-f9d7-48e9-94dd-bb50e7f1827a.png">
<img width="1505" alt="Screen Shot 2022-10-06 at 9 19 58 PM" src="https://user-images.githubusercontent.com/25019996/194453834-0c9b9dce-ec08-4710-97b9-f6221a46c752.png">

The live demo is at this link: https://e-chou.github.io/sdf-landscape/index.html 
but tbh it runs so slow that watching the video is probably preferable. I had to make the max steps very high because my clouds are pretty far away and also to get rid of artifacts from grazing angles so it runs stupidly slow.

Heres a quick explanation of how I created each feature:

Lighthouse: The lighthouse is made by hand using sdfs primitives (specifically capsule, capped cone, and torus). The main fun was toon shading it, which I did by taking abs dot coefficient and using whether it passed certain thresholds to determine what color to use, which gave it a stepped look.

Water: The water was created by warping a plane with fbm and offsetting it twice (in time and space) very slightly to get differet surfaces to shade different colors. I also added a goofy little cartoon wave shape in the back (combination of different math functions) to add a little playfulness to the water. Over time, the water has a small up and down wave motion as well as high and low tides that come more gradually. I shaded "sea foam" near the shore that syncs with the small waves by creating an offset sdf function for the hill (slightly bigger and to the right, up, and forward) and shading water that would be inside this proxy hill with a light colored overlay. The intensity of this overlay syncs with the small wave motion to make it seem like sea foam being created by the waves. 

Hill: The hill is a sphere thats been sculpted using fbm, toolbox functions, and some transformations of input positions. I use two different fbm functions to preturb the y coordinate of the position used to differentiate between grass, dirt, and sand, which give the wavy lines between the transitions. Then, I use a combination of how much the points are facing camera and how much they're facing the light (found with dot products) to shade the different features. I tried to shade them similarly enough that they're cohesive, but differently enough that the color changes don't always line up for the different types of material on the hill.

Clouds: Each cloud is the same set of spheres preturbed with fbm which is based on position. I animate them by changing their center position over time, which also makes their shape morph over time. To shade the clouds I used dot products to find how much points were facing the camera and facing the light, and combined these values (along with a stepped effect) to get cartoon shading that emphasized their shape. 

Background sky: For the background I used fbm to mix between two different shades of blue. To get the stepped cartoon look, I multiplied my mix amount by the number of colors I wanted, floored it, and then divided it by number of colors again.

Day/Night: The lighting for the scene moves over time to simulate a day/night cycle. The colors of the various scene features also change in sync with this change. 

If I were to continue editing this, my main priorties would be:

- Optimizing it bettter so its not so slow (change scale of clouds instead of having them so far away, minimize grazing angles or find other ways to speed up that edge case). This is the top priority by far bc omg it runs like a slug right now :/

- Making the clouds not morph so weirdly. I had to really crank up the noise to make them look different from eachother, but that resutls in weird moving as they travel across the screen. I want to change the function that generates them to warp the input position to the fbm that distorts them so they change more gradually as they move. 

- Add a sun/moon that move as day and night change to emphasize the transition, and maybe add some nice sunset/sunrise colors at the transitions between day and night.

- I rly want to add a boat :O like imagine how cute it would be to have a boat come bob along a sin wave down the screen every now and then 

# Project 2: SDFs

## Objective

Practice using raymarching, SDFs, and toolbox functions to sculpt a *beautiful* 3d landscape. 

## Set up your raymarcher

* Starting with the base code, create a ray marcher that can accurately render 3d shapes. We recommend testing with a sphere at the center of your canvas
* Add normal computation to properly shade your geometry. Start with lambert shading
* Add basic raymarching optimizations: use sphere-tracing, limit the number of maximum steps to avoid infinite loop

## Add basic scene elements

Using what you've learned about toolbox functions and sdfs:
* Create a noise-based terrain with height-based coloration that suggests at least 3 distinct terrain features (for example, the lowest portions of your terrain can be water and the highest, white-colored icecaps.). Feel free to get creative and do a non-realistic or stylized scene.
    * You must use at least 3 different toolbox functions, such as bias/gain or a wave function. At this point we expect you to be comfy using such functions to modify shape.
* Create a backdrop / sky where there is no terrain. For example, an interesting gradient with some kind of noise.

## Lighting

* Using the 3-point lighting system (fill light, key light, and fake global illumination light), light your scene to bring it to life.

## Animation
Add some element of animation to your scene that ISN'T just changing terrain height. (Been there done that with the fireball!)

Suggestions:
* Animate the position of your lighting / sun to simulate a change in time of day. We recommend the sky change color in step with your lighting change.
* Animate the thresholds for different terrain features, to suggest rising tides, or melting ice-caps, or a seasonal change in foliage color. 
* If you elect to add clouds, animate the cloud positions to suggest wind.

## (Optional) Extra Credit

* Additional scene elements eg. a building or animal or trees. [easy-hard, depends]
   * Sculpting with sdfs can be fiddly, so trying to model something very precise may be frustrating. We suggest keeping it simple
   * If your models get heavy you may also need to add acceleration structures *bonus points!
* Add 3d translucent clouds to your sky. [hard, it will be fiddly and slow your program down A LOT]
* Add camera animation to create a fly-over effect [???]
   * Depending on how you set up your scene, this may be a pretty involved change because the terrain will have to look good EVERYWHERE not just at a fixed angle. #proceduralLessons).

## Submission

- Update README.md to contain a solid description of your project
- Publish your project to gh-pages. `npm run deploy`. It should now be visible at http://username.github.io/repo-name
- Create a [pull request](https://help.github.com/articles/creating-a-pull-request/) to this repository, and in the comment, include a link to your published project.
- Submit the link to your pull request on Canvas.
