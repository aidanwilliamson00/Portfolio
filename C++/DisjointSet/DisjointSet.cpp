// DisjointSet implementation using union by size and path compression
// By Aidan Williamson

#include "DisjointSet.h"
#include <iostream>

DisjointSet::DisjointSet(int numObjects)
{
    theArray.resize(numObjects,-1);
    numValues=numObjects;
}

//recursive method to find the item -- does path compression on the way out of the recursion
int DisjointSet::find(int objectIndex)
{
    if(theArray[objectIndex]>=0){
        theArray[objectIndex]=find(theArray[objectIndex]);//path compression
    }else{
        return objectIndex;//root found
    }
}

bool DisjointSet::doUnion(int objIndex1, int objIndex2)
{
    if(theArray[objIndex1]>=0||theArray[objIndex2]>=0){//makes sure both indices are roots
        doUnion(find(objIndex1),find(objIndex2));
    }else if(objIndex1==objIndex2){
        return false;
    }else if(theArray[objIndex1]<=theArray[objIndex2]){//index 1 is larger set
        int temp=theArray[objIndex2];
        theArray[objIndex2]=objIndex1;
        theArray[objIndex1]+=temp;
        if(theArray[objIndex1]==(-1)*(numValues)){return true;}
        else{return false;}
    }else{//                                            index 2 is larger set
        int temp=theArray[objIndex1];
        theArray[objIndex1]=objIndex2;
        theArray[objIndex2]+=temp;
        if(theArray[objIndex2]==(-1)*(numValues)){return true;}
        else{return false;}
    }
}

void DisjointSet::printArrayValues(std::ostream &outputStream)
{
    for (int i = 0; i < numValues; i++)
    {
        outputStream << theArray[i] << " ";
    }
    outputStream << std::endl;
}
