# specify target here (name of executable)
TARG1 = tsh
# specify compiler, compile flags, and needed libs
CC = gcc
OPTS = -Wall -O
LIBS = -lm
# all is not really needed, but is used to generate the target
all: $(TARG1)
# this generates the target executable
$(TARG1): tsh.c
	$(CC) -o $(TARG1) tsh.c $(LIBS)

# and finally, a clean line
clean:
	rm -f $(TARG1)
