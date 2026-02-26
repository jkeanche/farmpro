#!/bin/bash

echo "Building Inuka Admin Application..."
echo ""

mvn clean package

if [ $? -eq 0 ]; then
    echo ""
    echo "Build successful!"
    echo ""
    echo "The executable JAR file is located at:"
    echo "target/InukaAdmin-1.0-SNAPSHOT-jar-with-dependencies.jar"
    echo ""
    echo "To run the application:"
    echo "java -jar target/InukaAdmin-1.0-SNAPSHOT-jar-with-dependencies.jar"
    echo ""
else
    echo ""
    echo "Build failed! Please check the error messages above."
    echo ""
fi
