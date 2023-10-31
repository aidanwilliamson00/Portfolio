// simple C++ program to build a doubly linked list from a file of longs,
// sort the list using insertion sort, and then write the sorted data
// to a file
// By Aidan Williamson

#include <fstream>
#include <iostream>
#include <cstdlib>
using namespace std;


struct Node
{
    private:
        long dataVal;
    public:
        Node* next;
        Node* prev;

        Node(long data = 0, Node* nextPtr = nullptr, Node* prevPtr = nullptr)
            : dataVal(data), next(nextPtr), prev(prevPtr) {}
        
        //Getter for public access of the dataVal
        long getDataVal() const { return dataVal; }
};

// read the file into the linked list
void readFile(Node*& head, char* fileName);

// write the linked list to the file
void writeFile(Node* head, char* fileName);

void insertionSort(Node*& head);


int main(int argc, char** argv) {

    if (argc < 3) {
        cout << "Usage: " << argv[0] << " infile outfile\n";
        exit(1);
    }
    char* inFileName = argv[1];
    char* outFileName = argv[2];
    Node* head = nullptr;

    readFile(head, inFileName);

    insertionSort(head);

    writeFile(head, outFileName);

    // clear out the list memory
    Node* temp = head;
    while (head)
    {
        head = head->next;
        delete temp;
        temp = head;
    }

    return 0;
}

void readFile(Node*& head, char* fileName)
{
    ifstream inFile(fileName);
    string line;
    Node* temp;
    while(getline(inFile,line)){
        Node* newNum = new Node(stol(line),nullptr,temp);
        if(!head){
            head=newNum;
            head->prev=nullptr;
            temp=head;
        }else{
            temp->next=newNum;
            temp=temp->next;
        }
    }
}

void writeFile(Node* head, char* fileName)
{
    ofstream outFile(fileName);
    Node* temp=head;
    while(temp){
        outFile<<temp->getDataVal()<<endl;
        temp=temp->next;
    }
}

void insertionSort(Node*& head)
{
    Node* temp=head->next;
    Node* curNode=temp;
    Node* curPtr=head;
    bool moves=false;
    while(temp){//starts at second value because the first value is "sorted"
        curNode=temp;
        temp=temp->next;
        curPtr=curNode->prev;
        while(curPtr->getDataVal()>curNode->getDataVal()&&curPtr){//finds curNode place in sorted list
            moves=true;
            if(curPtr->prev==nullptr){
                curPtr=nullptr;
                break;
            }else{
                curPtr=curPtr->prev;
            }
        }
        if(moves){//if a move needs to be made
            //repoint values before and after curNode
            if(curNode->next!=nullptr){
                curNode->next->prev=curNode->prev;
            }
            curNode->prev->next=curNode->next;
            if(curPtr==nullptr){//move curNode to head
                curNode->next=head;
                curNode->prev=nullptr;
                head->prev=curNode;
                head=curNode;
            }else{
                curPtr->next->prev=curNode;
                curNode->next=curPtr->next;
                curNode->prev=curPtr;
                curPtr->next=curNode;
            }
            moves=false;
        }
    }
}
