### This is a specific construct where the fire while to catch will be the one to run. Then once you stop the loop, control resumes after the chain of whiles. So only one of the while's is run. If none of the while conditions trigger, then the optional else loop will run until broken out of ###
while a > b

elswhile b > c

elswhile c < d

else

}


### I like this better, the spacing is easier on the eyes. I also like only using else. Two keywords are easier to remember than if elsif else.
###
when 1 > 2

else 2 > 3

else 3 > 4

else

}

if 1 > 2 # alternate

else 2 > 3

else 3 > 4

else

}
