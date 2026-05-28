# WorkLog++

A lightweight shell script app that is used to monitor the activities throught the day.

## Problem

Before that, i used a simple .md file with all working days and small summary of the day.
When typing `wlog` in `/home/my_user/`, automatically opened vs code inside a folder `wk_log` with a single file in it (`daily_summary.md`) having content like following:

```md
### 27.05.2026

- [x] Test LIA loading bay (most of the day) monitor duration for prefiltering
- [x] Disscution with manuel. try to save images during magnification calibration
- [x] Small test with docker image for CAR created on OpenShift

### 28.05.2026

- [ ] Waiting magnification target images from manuel
- [ ] Try to build other pipelines
- [ ] Build other docker images on openshift. (pra + regression suite + coverage report generator)

### 29.05.2026

--------------------
## June 2026

### 02.06.2026

### 03.06.2026

### 04.06.2026
```

This is not that much convinient. Takes time to open the vs code and so on..

## Idea

I want to have a simple sh app that can provide for me, from anywhere in the machine, the possibility to make writes and reads of my working activities. for example:

```sh
wlog
```
>this should output in the command line, pretty printed, the activities (checked or not) for **today** and **yesterday**
```sh
wlog -y
```
> same but for yesterday
```sh
wlog +
```
> this should open a TUI like a text box to specify a new activity to add for today. It should work with ```-y``` or ```-p``` or ```-f``` or similar date selectors

```sh
wlog -c 
```
> this should open a small TUI to check the activities from today, yesterday and tommorow (in a cronological order, colored slightly different. the coloration should be easily changble via a css like file. not necesarrily css)
> the TUI should contain also a text box with the availability to select from a combo the date (default today). Near that a button of "yesterday" that automatically selects from combo the yesterday date. also same for "tommorow"

```sh
wlog -p 5
```
> this is like all the above but five days before (yesterday is the same as -n 1). p stands for past

```sh
wlog -f 5
```
> future
> 
```sh
wlog -t
```
> tommorow 

```
wlog -h
```
> in case i forgot the commands

Furthermore, all the information should be stored in an .md file, ready to preview:

```wlog -a``` whould open the equivalent ```.html``` file of the ```md``` work log in the windows browser edge (i'm on WSL right now)

