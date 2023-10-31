#include <sys/types.h>
#include <sys/wait.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <unistd.h>
#include <string.h>
#include <fcntl.h>
#include <limits.h>

void errmsg(){
  char error_message[] = "An error has occured (from AW)\n";
  write(STDERR_FILENO, error_message, strlen(error_message));
}

struct LLnode{
  char* data;
  struct LLnode* next;
};

int main(int argc,char* argv[]){

  int exectype=0;//0 for execvp, 1 for execlp
  char* buffer;
  char* copy;
  char* history;
  char** path;
  size_t buffersize = 32;
  size_t numread = 0;
  bool done = false;
  bool intcmd = false;
  int i,j;
  int numpaths = 0;
  struct LLnode* head = (struct LLnode*)malloc(sizeof(struct LLnode));
  struct LLnode* curNode = NULL;
  int historySize = 0;

  if(argc>2){
    printf("Too many arguments.");
    return(0);
  }else if(argc == 2){
    if(strcmp(argv[1],"-execlp") == 0){
      exectype = 1;
      printf("**Based on your choice, execlp() will be used**\n");
    }else{
      printf("**Based on your choice, execvp() will be used**\n");
    }
  }else{
    printf("**Based on your choice, execvp() will be used**\n");
  }

  buffer = (char*)malloc(buffersize * sizeof(char));
  copy = (char*)malloc(buffersize * sizeof(char));
  history = (char*)malloc(buffersize * sizeof(char));

  while(!done){
    intcmd = false;
    printf("tsh > ");
    numread = getline(&buffer,&buffersize,stdin);

    if(numread > 1){
      //copy input
      strcpy(copy,buffer);
      strcpy(history,buffer);
      //tokenize to count number of args
      char* token = strtok(buffer," :\t\n");
      char* cmd = token;
      int argnum = 0;
      while(token != NULL){
        argnum++;
        token = strtok(NULL," :\t\n");
      }
      //tokenize copy to add args to array
      char* args[argnum];
      char* ctoken = strtok(copy," :\t\n");
      i=0;
      while(ctoken != NULL){
        args[i]= ctoken;
        ctoken = strtok(NULL," :\t\n");
        i++;
      }

      //history add
      struct LLnode* newNode = (struct LLnode*)malloc(sizeof(struct LLnode));
      char* newData = (char*)malloc(sizeof(history));
      strcpy(newData,history);
      newNode->data = newData;
      curNode = head;
      if(historySize == 0){
        head->next = newNode;
        historySize++;
      }else{
        while(curNode->next != NULL){
         curNode = curNode->next;
        }
        curNode->next = newNode;
        historySize++;
        if(historySize>50){
          head = head->next;
        }
      }




      //exit
      if(strcmp(cmd,"exit") == 0){
        intcmd = true;
        if(argnum==1){
          exit(0);
        }
        errmsg();
      }

      //cmd interpret
      if(strcmp(cmd,"cat") == 0){
        if(argnum==3){
          if(*args[1]=='<'){
            char* newcmd = "/bin/cat";
            cmd = newcmd;
            args[0] = cmd;
            args[1] = args[2];
            argnum--;
          }else{
            errmsg();
          }
        }else{
          errmsg();
        }
      }

      if(strcmp(cmd,"cd") == 0){
        intcmd = true;
        if(argnum>2||argnum==1||chdir(args[1])!=0){
          errmsg();
        }
      }

      if(strcmp(cmd,"path") == 0){
        intcmd = true;
        if(argnum==1){
          if(numpaths>0){
            printf("path is set to ");
            for(i=0;i<numpaths;i++){
              if(i==numpaths-1){
                printf("%s",path[i]);
              }else{
                printf("%s:",path[i]);
              }
            }
            printf("\n");
          }else{
            printf("no path set\n");
          }
        }else{

          numpaths = argnum-1;
          path = (char**)malloc(numpaths * sizeof(char*));
          for(i=0;i<numpaths;i++){
            char* newstr = (char*)malloc(sizeof(args[i+1]));
            strcpy(newstr,args[i+1]);
            path[i]=newstr;
          }
        }
      }

      if(strcmp(cmd,"history") == 0){
        intcmd = true;
        if(argnum==1){
          j=historySize;
          curNode = head->next;
          while(curNode != NULL){
            printf("%d: %s",j,curNode->data);
            curNode = curNode->next;
            j--;
          }
        }else if(argnum==2){
          int num = atoi(args[1]);
          if(num>0 && num<51){
            curNode = head->next;
            for(i=0;i<num;i++){
              if(curNode != NULL){
                printf("%d: %s",historySize-i,curNode->data);
                curNode = curNode->next;
              }else{
                printf("%d: NULL\n",i+1);
              }
            }
          }
        }else{
          errmsg();
        }
      }

      if(!intcmd){

        pid_t pid;
        pid = fork();

        if(pid < 0){
          errmsg();
          exit(-1);
        }
        else
          if(pid == 0) //child
          {
            char* cmdtouse="";
            bool pfound = false;

            if(access(cmd,X_OK)==0){
              pfound = true;
              cmdtouse = cmd;
            }
            if(numpaths>0){
              for(i=0;i<numpaths;i++){
                if(strcmp(path[i],"./") == 0){
                  cmdtouse = strcat(path[i],cmd);
                }else{
                  cmdtouse = strcat(path[i],"/");
                  cmdtouse = strcat(cmdtouse,cmd);
                }
                if(access(cmdtouse,X_OK)==0){
                  pfound = true;
                  break;
                }
              }
            }


            if(pfound){
              //cmd exec
              if(exectype==0){
                char* vpargs[argnum+1];
                vpargs[0]=cmdtouse;
                for(i=1;i<argnum;i++){
                  vpargs[i]=args[i];
                }
                vpargs[argnum] = NULL;
                if(execvp(vpargs[0],vpargs)==-1){
                  errmsg();
                  exit(127);
                }
              }else{
                char* lpargs[5] = {cmdtouse,NULL,NULL,NULL,NULL};
                for(i=1;i<argnum;i++){
                  lpargs[i]=args[i];
                }
                if(execlp(cmdtouse,lpargs[0],lpargs[1],lpargs[2],lpargs[3],lpargs[4],NULL)==-1){
                  errmsg();
                  exit(127);
                }
              }
            }else{
              errmsg();//invalid command
              exit(127);
            }
          }
          else //parent
          {
            wait(0);
          }
        }
      }
  }
  return(0);
}
