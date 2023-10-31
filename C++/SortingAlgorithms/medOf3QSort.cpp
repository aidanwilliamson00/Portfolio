// simple C++ program to read in an array of longs, sort
// the array using quicksort (with median of 3 and cutoffs of 50), 
// and then write the sorted data to a file
// By Aidan Williamson

#include <iostream>
#include <fstream>
#include <cstdlib>
#include <vector>
using namespace std;

// read the file into the vector
void readFile(vector<long>& arr, char* fileName);

// write the vector to the file
void writeFile(const vector<long>& arr, char* fileName);

// sort the specified partition of the vector using quicksort
// left and right are the first and last index of the partition to sort
void quicksort(vector<long>& arr, int left, int right);

void insertionSort(vector<long>& arr,int left,int right);

int main(int argc, char** argv) {

  if (argc < 3) {
    cout << "Usage: " << argv[0] << " infile outfile\n";
    exit(1);
  }
  char* inFileName = argv[1];
  char* outFileName = argv[2];
  vector<long> theArray;
  
  readFile(theArray, inFileName);

  quicksort(theArray,0,theArray.size()-1);
  
  writeFile(theArray, outFileName);

  return 0;
}

void readFile(vector<long>& arr, char* fileName)
{
  ifstream inFile(fileName);
  string line;
  while(getline(inFile,line)){
    arr.push_back(stol(line));
  }
}

void writeFile(const vector<long>& arr, char* fileName)
{
  ofstream outFile(fileName);
  for(int i=0;i<arr.size();i++){
    outFile<<arr[i]<<endl;
  }
}

void quicksort(vector<long>& arr,int left, int right)
{

  int i, j;
  long pivot;
  long temp;

  if (right - left > 49) {//if there is more than 50 values use quicksort

    int mid=(left+right)/2;
    //sort first, middle, and last elements

    if(arr[left]>arr[mid]){
      temp=arr[mid];
      arr[mid]=arr[left];
      arr[left]=temp;
    }
    if(arr[left]>arr[right]){
      temp=arr[right];
      arr[right]=arr[left];
      arr[left]=temp;
    }
    if(arr[mid]>arr[right]){
      temp=arr[right];
      arr[right]=arr[mid];
      arr[mid]=temp;
    }
    //move median to right-1
    temp=arr[right-1];
    arr[right-1]=arr[mid];
    arr[mid]=temp;

    pivot = arr[right-1]; //median is pivot
    i = left; // set at beginning so first call is one to the right of start
    j = right-1; // set at pivot, first call is one to the left

    //we're going to tolerate an infinite loop here and use break
    while (true)
    {
      // pre-increment i until arr[i] is >= the pivot
      while ( arr[++i] < pivot );

      // post-decrement j until arr[j] is <= the pivot
      while ( j > 0 && arr[--j] > pivot );

      //if i and j have crossed -- get out of the loop
      if (i >= j)
        break;

      // otherwise, swap a[i] and a[j]
      temp = arr[i];
      arr[i] = arr[j];
      arr[j] = temp;
    }

    // i and j have crossed, so swap a[i] and the pivot
    arr[right-1] = arr[i];
    arr[i] = pivot;

    // the pivot is now in place at i
    // now call quicksort on the two partitions
    quicksort(arr, left, i); // left partition
    quicksort(arr, i, right); // right partition
  }else{//50 or less use insertion
    insertionSort(arr,left,right);
  }
}

void insertionSort(vector<long>& arr,int left,int right){
  int cur=left+1;
  int temp=left;
  bool move=false;
  while(cur<=right){
    while(arr[cur]<arr[temp]){
      move=true;
      if(temp==left){
        temp--;
        break;
      }
      temp--;
    }
    if(move){
      long val=arr[cur];
      arr.erase(arr.begin()+cur);
      arr.insert(arr.begin()+temp+1,val);
      move=false;
    }
    cur++;
    temp=cur-1;
  }
}
