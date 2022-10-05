#Live Demo: https://logancho.github.io/hw02-landscape/

Status: Incomplete ... (no colouring implemented) but I'm still really proud of what I managed to create, and will probably be working on it for a lot longer after this deadline since I really want to see the finished product.

Summary: I wanted to do a scenic train environment, with mountains of different sizes moving in a sort of parallax affected type of way in the background. I accomplished the noise of the 2 layers of my mountains by using an fbm noise generator built off of IQ's 'voronoise' function from Shadertoy. It was really, really difficult for me at first when I was trying to interpolate between the flat plane into the two layers of mountains, since the SDFs became full of weird holes and errors unless the transition was incredibly smooth. This is where the toolbox functions, especially easing, came really in handy, as by adjusting the interpolation of the noise with the easing functions, I was able to have smooth transitions that didn't cause as many holes in the ray marching process. For the telephone poles, they're unfinished, but I used IQ's modulo repetition that Adam explained to me during this Monday's lecture.

I also used fog, similar to Adam's example last week on Shadertoy, to help the further, larger mountains fade into the background a little better.

Overall, I really want to see this scene coloured, and also maybe performing a little better (planning on going to OH this week to ask for some tips on areas I could optimize) but my head hurts, and I haven't seen my bed in a while so I think this will do for tonight : ) !

# Late Day: 10/03/22 - I will be using the first of my 3 late days on this assignment.
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
