//Graph Class
//By: Aidan Williamson

#include "Graph.h"
#include "DisjointSet.h"
#include <iostream>
#include <fstream>
#include <vector>
#include <queue>
#include <tuple>

using namespace std;

Graph::Graph(){

}

int Graph::findVertex(string& name){
    for(int i=0;i<nodeNames.size();i++){
        if(nodeNames[i]==name){
            return i;
        }
    }
    return -1;
}

bool Graph::readGraph(string& fileName){
    if(!matrix.empty()){
        matrix.clear();
        nodeNames.clear();
        numVertices=0;
        numEdges=0;
    }
    ifstream infile(fileName);
    if(infile.fail()){
        return false;
    }
    //read first line into numVertices
    string line;
    getline(infile,line);
    numVertices=stoi(line);
    //read numVertices of lines into nodeNames
    for(int i=0;i<numVertices;i++){
        getline(infile,line);
        nodeNames.push_back(line);
    }
    //read next line into numEdges
    getline(infile,line);
    numEdges=stoi(line);
    //resize matrix to fit edges
    matrix.resize(numVertices);
    for(int i=0;i<numVertices;i++){
        matrix[i].resize(numVertices);
    }
    //read numEdges of lines and enter data into matrix
    for(int i=0;i<numEdges;i++){
        getline(infile,line);
        int lineIter=0;
        int wordIter=0;
        //Find first vertex from line and find index
        for(lineIter=wordIter;!isspace(line[wordIter]);wordIter++){}
        string vertex1=line.substr(lineIter,wordIter-lineIter);
        int vert1Index=findVertex(vertex1);
        //Find second vertex from line and find index
        wordIter++;
        for(lineIter=wordIter;!isspace(line[wordIter]);wordIter++){}
        string vertex2=line.substr(lineIter,wordIter-lineIter);
        int vert2Index=findVertex(vertex2);
        //Find weight from line
        wordIter++;
        for(lineIter=wordIter;!isspace(line[wordIter]);wordIter++){}
        int weight=stoi(line.substr(lineIter,wordIter-lineIter));
        //Use indices to set weight in adjacency matrix
        matrix[vert1Index][vert2Index]=weight;
        //repeat until all edges have been entered
    }

    
}
void Graph::printGraph(){
    cout<<numVertices<<endl;
    for(int i=0;i<numVertices;i++){
        cout<<nodeNames[i]<<endl;
    }
    cout<<numEdges<<endl;
    for(int i=0;i<numVertices;i++){
        for(int j=0;j<numVertices;j++){
            if(matrix[i][j]){
                cout<<nodeNames[i]<<" "<<nodeNames[j]<<" "<<matrix[i][j]<<endl;
            }
        }
    }
}

void Graph::computeTopologicalSort(){
    queue<int> vertIndex;
    queue<int> topoSort;
    //create list of num of indegrees to each vertex
    int indegrees[numVertices];
    for(int i=0;i<numVertices;i++){
        indegrees[i]=0;
    }
    for(int i=0;i<numVertices;i++){
        for(int j=0;j<numVertices;j++){
            if(matrix[i][j]){
                indegrees[j]++;
            }
        }
    }
    //if any of the indegrees are 0 add to queue
    for(int i=0;i<numVertices;i++){
        if(indegrees[i]==0){
            vertIndex.push(i);
        }
    }
    //while queue has items, remove item from queue and add it to final queue
    while(!vertIndex.empty()){
        int cur=vertIndex.front();
        vertIndex.pop();
        topoSort.push(cur);
        //decrement all vertices that connect to cur vertex
        for(int i=0;i<numVertices;i++){
            if(matrix[cur][i]){
                indegrees[i]--;
                if(indegrees[i]==0){//if vertex reaches 0 indegrees add it to queue
                    vertIndex.push(i);
                }
            }
        }

    }
    if(topoSort.size()!=numVertices){
        cout<<"This graph cannot be topologically sorted.\n";
    }else{
        cout<<"Topological Sort:\n";
        for(int i=0;i<numVertices;i++){
            if(i==numVertices-1){
                cout<<nodeNames[topoSort.front()]<<endl;
                topoSort.pop();
            }else{
                cout<<nodeNames[topoSort.front()]<<" --> ";
                topoSort.pop();
            }
        }
    }

}

void Graph::computeShortestPaths(string& nodeName){
    int index=findVertex(nodeName);
    vector<string> paths[numVertices];
    int counter=1;
    if(index<0){cout<<"Vertex does not exist"<<endl;return;}
    //create a priority queue of type tuple(cost,vertexFrom,vertexTo)
    std::priority_queue<tuple<int,int,int>,vector<tuple<int,int,int>>,greater<tuple<int,int,int>>> priQueue;
    for(int i=0;i<numVertices;i++){//push all vertices connected to origin into queue
        if(matrix[index][i]){
            tuple<int,int,int> entry;
            entry = make_tuple(matrix[index][i],index,i);
            priQueue.push(entry);
        }
    }
    while(priQueue.size()>0||counter<numVertices){//while queue has items or not all paths have been found
        tuple<int,int,int> top=priQueue.top();
        priQueue.pop();
        while(!paths[get<2>(top)].empty()){//if path for vertex already exists go next
            if(priQueue.size()==0){
                break;
            }
            top=priQueue.top();
            priQueue.pop();
        }
        if(!paths[get<2>(top)].empty()){
            break;
        }
        counter++;
        //Ideal path where root is one edge away
        paths[get<2>(top)].push_back(to_string(get<0>(top)));
        paths[get<2>(top)].push_back(nodeNames[get<2>(top)]);
        paths[get<2>(top)].push_back(nodeNames[get<1>(top)]);
        if(get<1>(top)!=index){//if path is not direct to start, we need to find full path
            for(int i=2;i<paths[get<1>(top)].size();i++){
                paths[get<2>(top)].push_back(paths[get<1>(top)][i]);
            }
        }
        //after path has been created and stored we want to continue from current vertex.
        for(int i=0;i<numVertices;i++){//push all vertices connected to new vertex to queue
            if(matrix[get<2>(top)][i]){
                tuple<int,int,int> entry;
                entry = make_tuple(matrix[get<2>(top)][i]+stoi(paths[get<2>(top)][0]),get<2>(top),i);
                priQueue.push(entry);
            }
        }
    }
    cout<<"Shortest paths from "<<nodeName<<":\n";
    for(int i=0;i<numVertices;i++){
        if(i!=index){
            if(paths[i].size()>0){
                for(int j=paths[i].size()-1;j>1;j--){
                    cout<<paths[i][j]<<" --> ";
                }
                cout<<paths[i][1]<<" || Weight: "<<paths[i][0]<<"\n";
            }else{
                cout<<"No path from "<<nodeName<<" to "<<nodeNames[i]<<" found.\n";
            }
        }
    }
}

void Graph::computeMinimumSpanningTree(){
    DisjointSet minTree(numVertices);
    std::priority_queue<tuple<int,int,int>,vector<tuple<int,int,int>>,greater<tuple<int,int,int>>> priQueue;
    bool minTreeComplete=false;
    int totalWeight=0;
    //create ordered list of edges
    for(int i=0;i<numVertices;i++){
        for(int j=0;j<numVertices;j++){
            if(matrix[i][j]){
                tuple<int,int,int> entry;
                entry = make_tuple(matrix[i][j],i,j);
                priQueue.push(entry);
            }
        }
    }
    //create minTree by pulling shortest edges from list and union
    //  must not be in same set already
    cout<<"Minimum Spanning Tree:\n";
    while(!minTreeComplete&&!priQueue.empty()){
        tuple<int,int,int> top=priQueue.top();
        priQueue.pop();
        if(minTree.find(get<1>(top))!=minTree.find(get<2>(top))){
            cout<<nodeNames[get<1>(top)]<<" -- "<<nodeNames[get<2>(top)]<<" || Weight: "<<get<0>(top)<<"\n";
            totalWeight+=get<0>(top);
            minTreeComplete=minTree.doUnion(get<1>(top),get<2>(top));
        }
    }
    cout<<"Total Cost: "<<totalWeight<<"\n";
}
