//Graph Header file
//By: Aidan Williamson
#ifndef GRAPH_H
#define GRAPH_H
#include <vector>
#include <string>
#include <iostream>

using namespace std;

class Graph{
    private:
        vector<vector<int>> matrix;
        vector<string> nodeNames;
        int numVertices;
        int numEdges;
    public:
        //Constructor
        Graph();
        //Returns index of vertex with name, if vertex does not exist, -1
        int findVertex(string& name);
        //reads file into new graph clearing any existing data
        bool readGraph(string& fileName);
        //prints graph in same format as input. 
        //      When printing edges, all edges from one vertex will be printed before the next vertexs edges are printed.
        void printGraph();
        //computes and prints topological sort, if its not possible print so.
        void computeTopologicalSort();
        //computes and prints shortest paths to all vertices from given vertex
        void computeShortestPaths(string& nodeName);
        //computes and prints minimum spanning tree
        void computeMinimumSpanningTree();
};
#endif
