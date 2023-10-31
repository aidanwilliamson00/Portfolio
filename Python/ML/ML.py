#IT 348/448 ML Project
#By: Aidan Williamson

import functools

def readMetaData(lines):#puts meta data into a readable array
    lineCount=len(lines)
    arr=[0]*(lineCount)
    lineCount=0
    for line in lines:
        line = line.split()
        curLine = line[0].split(":")
        words=curLine[1].split(",")
        words.insert(0,curLine[0])
        arr[lineCount]=words
        lineCount=lineCount+1
    return arr

def createAttrTables():#accessed by attrTables[attribute][class][attrVal] and classTable[class]
    classSize = len(metaArr[len(metaArr)-1])-1
    attrTables = [0 for i in range(len(metaArr)-1)]
    for attr in range(len(metaArr)-1):
        attrTables[attr] = [[0 for i in range(len(metaArr[attr])-1)]for j in range(classSize)]
    classTable = [0 for i in range(classSize)]
    return attrTables,classTable


def populateTables(lines):#populates tables with training file data
    classSize = len(metaArr[len(metaArr)-1])-1
    attrSize = len(metaArr)-1
    
    for line in lines:
        line = line.split()
        curLine = line[0].split(",")
        curClassIndex = -1
        for i in range(classSize):
            if(curLine[attrSize]==metaArr[attrSize][i+1]):
                classTable[i]=classTable[i]+1
                curClassIndex = i
        for i in range(attrSize):
            for j in range(len(attrTables[i][curClassIndex])):
                if(curLine[i]==metaArr[i][j+1]):
                    attrTables[i][curClassIndex][j]=attrTables[i][curClassIndex][j]+1
    #tables populated, now we smooth
    for i in range(attrSize):
        for j in range(classSize):
            for k in range(len(attrTables[i][j])):
                attrTables[i][j][k]=attrTables[i][j][k]+1
    #tables smoothed, now we calculate percentages
    classTotal = functools.reduce(lambda x,y:x+y,classTable)
    for i in range(classSize):
        classTable[i]=classTable[i]/classTotal
    for i in range(attrSize):
        for j in range(classSize):
            attrTotal = functools.reduce(lambda x,y:x+y,attrTables[i][j])
            for k in range(len(attrTables[i][j])):
                attrTables[i][j][k]=attrTables[i][j][k]/attrTotal
    return attrTables,classTable

def clearTables():#clears training data 
    classSize = len(metaArr[len(metaArr)-1])-1
    attrSize = len(metaArr)-1
    for i in range(classSize):
        classTable[i]=0
    for i in range(attrSize):
        for j in range(classSize):
            for k in range(len(attrTables[i][j])):
                attrTables[i][j][k]=0

def classifyFile(inFileName,outFileName):
    classSize = len(metaArr[len(metaArr)-1])-1
    attrSize = len(metaArr)-1
    inFile = open(inFileName)
    outFile = open(outFileName,"x")
    lines = inFile.readlines()
    
    for line in lines:
        line = line.split()
        curLine = line[0].split(",")
        for i in range(attrSize):
            outFile.write(curLine[i]+",")
        #attributes written to outfile, now we add classification
        maxClassIndex=-1
        maxClassVal=0
        for i in range(classSize):
            mapCalc=classTable[i]
            for j in range(attrSize):
                for k in range(len(attrTables[j][i])):
                    if(curLine[j]==metaArr[j][k+1]):
                        mapCalc = mapCalc * attrTables[j][i][k]
            if mapCalc > maxClassVal:
                maxClassVal=mapCalc
                maxClassIndex=i
        outFile.write(metaArr[attrSize][maxClassIndex+1]+"\n")

def testMetrics(lines):
    classSize = len(metaArr[len(metaArr)-1])-1
    attrSize = len(metaArr)-1     
    numCorrect=0
    numTotal=0
    for line in lines:
        line = line.split()
        curLine = line[0].split(",")
        maxClassIndex=-1
        maxClassVal=0
        for i in range(classSize):
            mapCalc=classTable[i]
            for j in range(attrSize):
                for k in range(len(attrTables[j][i])):
                    if(curLine[j]==metaArr[j][k+1]):
                        mapCalc = mapCalc * attrTables[j][i][k]
            if mapCalc > maxClassVal:
                maxClassVal=mapCalc
                maxClassIndex=i
        predictedClass = metaArr[attrSize][maxClassIndex+1]
        if(predictedClass==curLine[attrSize]):
            numCorrect=numCorrect+1
            numTotal=numTotal+1
        else:
            numTotal=numTotal+1
    accuracy = (numCorrect/numTotal)*100
    print("Accuracy is: %3.3f\n"%(accuracy))
    return accuracy

def kFold(lines,num):
    lineSize = int((len(lines)-(len(lines)%num))/num)

    totalAccuracy=0
    maxAccuracy=0
    curAccuracy=0

    curAttrTables=[]
    curClassTable=[]

    for i in range(num):
        clearTables()
        if i==0:
            trLines = lines[lineSize:]
            teLines = lines[0:lineSize]
            attrTables,classTable=populateTables(trLines)
            print("Fold #: ",i+1)
            curAttrTables=attrTables.copy()
            curClassTable=classTable.copy()
            curAccuracy = testMetrics(teLines)
            maxAccuracy=curAccuracy
            totalAccuracy+=curAccuracy
        elif i!=(num-1):
            trLines = lines[:lineSize*i]+lines[lineSize*(i+1):]
            teLines = lines[lineSize*i:lineSize*(i+1)]
            attrTables,classTable=populateTables(trLines)
            print("Fold #: ",i+1)
            curAccuracy = testMetrics(teLines)
            totalAccuracy+=curAccuracy
            if(curAccuracy>maxAccuracy):
                curAttrTables=attrTables.copy()
                curClassTable=classTable.copy()
                maxAccuracy=curAccuracy

        else:
            trLines = lines[:lineSize*(num-1)]
            teLines = lines[lineSize*(num-1):]
            attrTables,classTable=populateTables(trLines)
            print("Fold #: ",i+1)
            curAccuracy = testMetrics(teLines)
            totalAccuracy+=curAccuracy
            if(curAccuracy>maxAccuracy):
                curAttrTables=attrTables.copy()
                curClassTable=classTable.copy()
                maxAccuracy=curAccuracy
    
    attrTables=curAttrTables
    classTable=curClassTable
    print("Average accuracy is: %3.3f\n"%(totalAccuracy/num))

def confusionMatrix(lines):
    classSize = len(metaArr[len(metaArr)-1])-1
    attrSize = len(metaArr)-1
    conMat = [0]*classSize
    for i in range(classSize):
        conMat[i]=[0 for j in range(classSize)]
    numCorrect=0
    numTotal=0
    for line in lines:
        line = line.split()
        curLine = line[0].split(",")
        maxClassIndex=-1
        maxClassVal=0
        for i in range(classSize):
            mapCalc=classTable[i]
            for j in range(attrSize):
                for k in range(len(attrTables[j][i])):
                    if(curLine[j]==metaArr[j][k+1]):
                        mapCalc = mapCalc * attrTables[j][i][k]
            if mapCalc > maxClassVal:
                maxClassVal=mapCalc
                maxClassIndex=i
        predictedClass = metaArr[attrSize][maxClassIndex+1]
        if(predictedClass==curLine[attrSize]):
            conMat[maxClassIndex][maxClassIndex]+=1
            numCorrect=numCorrect+1
            numTotal=numTotal+1
        else:
            for m in range(classSize):
                if metaArr[attrSize][m+1]==curLine[attrSize]:
                    conMat[maxClassIndex][m]+=1
            numTotal=numTotal+1
    accuracy = (numCorrect/numTotal)*100
    print(end="\t")
    for i in range(classSize):
        print(metaArr[attrSize][i+1],end="\t")
    print()
    for i in range(classSize):
        print(metaArr[attrSize][i+1],end="\t")
        for j in range(classSize):
            print(conMat[i][j],end="\t")
        print()
    print("\nAccuracy is: %3.3f\n"%(accuracy))
    for i in range(classSize):
        precision=0
        recall=0
        tp=0
        fp=0
        fn=0
        print("Class: ",metaArr[attrSize][i+1])
        for j in range(classSize):
            if i==j:
                tp = conMat[i][j]
            else:
                fn+=conMat[i][j]
                fp+=conMat[j][i]
        precision = tp/(tp+fp)
        recall = tp/(tp+fn)
        print("  Precision: %3.3f"%(precision*100))
        print("  Recall: %3.3f"%(recall*100))
    print()

    
    


#main
running=True
classTable=[]
attrTables=[]
metaArr=[]
while(running):
    print("""Menu: (Enter number to choose)
    1. Train
    2. Classify
    3. Test Accuracy
    4. K-Fold Train
    5. Print Confusion Matrix
    6. Quit
    """)
    numIn = input()
    if(numIn=="1"):
        trainFileName=""
        metaFileName=""
        while(trainFileName=="" or metaFileName==""):
            print("Please enter training or meta file name:")
            stringIn = input()
            if(stringIn[-6:]==".train" and trainFileName==""):
                print("Valid training file\n")
                trainFileName=stringIn
            elif(stringIn[-5:]==".meta" and metaFileName==""):
                print("Valid meta file\n")
                metaFileName=stringIn
            elif(stringIn[-6:]==".train"):
                print("Training file already entered, please enter meta file\n")
            elif(stringIn[-5:]==".meta"):
                print("Meta file already entered, please enter training file\n")
            else:
                print("Not a valid input\n")
        metaFile = open(metaFileName)
        metaLines = metaFile.readlines()

        trainFile = open(trainFileName)
        trainLines = trainFile.readlines()

        metaArr = readMetaData(metaLines)
        #create tables to hold attribute and class data
        attrTables,classTable = createAttrTables()
        #populate tables
        attrTables,classTable = populateTables(trainLines)
        print("Meta data and training data successfully entered\n")

    elif(numIn=="2"):
        
        if(metaArr!=[] and attrTables!=[] and classTable!=[]):
            print("Please enter input file name:")
            inFile=input()
            print("Please enter desired output file name:")
            outFile=input()
            
            classifyFile(inFile,outFile)
        else:
            print("Please train first")
    elif(numIn=="3"):
        #take our classification file and compare it to classifications in the .train file
        #pre: 2 file inputs in same format
        #out: Accuracy, Precision, and Recall
        if(metaArr!=[] and attrTables!=[] and classTable!=[]):
            testFileName=""
            predictedFileName=""
            while(testFileName==""):
                print("Please enter test file name:")
                stringIn=input()
                if(stringIn[-5:]==".test"):
                    testFileName=stringIn
                else:
                    print("Not a vaild test file name")
            testFile = open(testFileName)
            testLines = testFile.readlines() 
            testMetrics(testLines)
        else:
            print("Please train first")
    elif(numIn=="4"):
        #k-fold here
        KtrainFileName=""
        KmetaFileName=""
        while(KtrainFileName=="" or KmetaFileName==""):
            print("Please enter training or meta file name:")
            stringIn = input()
            if(stringIn[-6:]==".train" and KtrainFileName==""):
                print("Valid training file\n")
                KtrainFileName=stringIn
            elif(stringIn[-5:]==".meta" and KmetaFileName==""):
                print("Valid meta file\n")
                KmetaFileName=stringIn
            elif(stringIn[-6:]==".train"):
                print("Training file already entered, please enter meta file\n")
            elif(stringIn[-5:]==".meta"):
                print("Meta file already entered, please enter training file\n")
            else:
                print("Not a valid input\n")
        KmetaFile = open(KmetaFileName)
        KmetaLines = KmetaFile.readlines()
        metaArr = readMetaData(KmetaLines)
        attrTables,classTable = createAttrTables()

        KtrainFile = open(KtrainFileName)
        KtrainLines = KtrainFile.readlines()
        print("Please enter the number of K-Folds you would like:")
        kNum = int(input())
        kFold(KtrainLines,kNum)

    elif(numIn=="5"):
        if(metaArr!=[] and attrTables!=[] and classTable!=[]):
            testFileName=""
            while(testFileName==""):
                print("Please enter test file name:")
                stringIn=input()
                if(stringIn[-5:]==".test"):
                    testFileName=stringIn
                else:
                    print("Not a vaild test file name")
            testFile = open(testFileName)
            testLines = testFile.readlines()
            confusionMatrix(testLines)
        else:
            print("Please train by using menu option 1 or 4 first")
    elif(numIn=="6"):
        running=False
    else:
        print("Not a valid input")
