// simple C++ program to read in an array of longs, sort
// the array using heapsort, and then write the sorted data
// to a file
// By Aidan Williamson

#include <fstream>
#include <iostream>
#include <cstdlib>
#include <vector>
using namespace std;

// read the file into the vector (starting at index 1)
void readFile(vector<long>& arr, char* fileName);

// write the vector to the file (starting at index 1)
void writeFile(const vector<long>& arr, char* fileName);

// sort the vector using heapsort (data starts at index 1)
void heapsort(vector<long>& arr);

// add any function prototypes for any additional functions here
void percolateDown(vector<long>& arr,int index);
long removeMin(vector<long>& arr);


int main(int argc, char** argv) {

  if (argc < 3) {
    cout << "Usage: " << argv[0] << " infile outfile\n";
    exit(1);
  }
  char* inFileName = argv[1];
  char* outFileName = argv[2];
  vector<long> theArray;
  
  readFile(theArray, inFileName);

  heapsort(theArray);
  
  writeFile(theArray, outFileName);

  return 0;
}

void readFile(vector<long>& arr, char* fileName)
{
  ifstream inFile(fileName);
  string line;
  int size=0;
  while(getline(inFile,line)){
    arr.push_back(stol(line));
    size++;
  }
  arr.insert(arr.begin(),size);

}

void writeFile(const vector<long>& arr, char* fileName)
{
  ofstream outFile(fileName);
  for(int i=1;i<arr.size();i++){
    outFile<<arr[i]<<endl;
  }
}

void heapsort(vector<long>& arr)
{
  vector<long> newArr;
  for(int i=(arr.size()-1)/2;i>0;i--){
    percolateDown(arr,i);
  }
  for(int i=(arr.size()-1);i>0;i--){
    newArr.push_back(removeMin(arr));
  }
  arr.swap(newArr);
  arr.insert(arr.begin(),arr.size()-1);
}

  
void percolateDown(vector<long>& arr,int index){
  int child;
  long temp=arr[index];
  while(index*2<=arr.size()-1){
    child=index*2;
    if(child!=arr.size()-1&&arr[child+1]<arr[child]){
      child++;
    }
    if(arr[child]<temp){
      arr[index]=arr[child];
    }else{
      break;
    }
    index=child;
  }
  arr[index]=temp;
}

long removeMin(vector<long>& arr){
  long val=arr[1];
  arr[1]=arr[arr.size()-1];
  arr.erase(arr.end()-1);
  percolateDown(arr,1);
  return val;
}
