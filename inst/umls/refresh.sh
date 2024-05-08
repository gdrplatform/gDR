# sudo apt-get install plantuml
# pretty old version
#jar_path="/usr/share/platinuml/platinuml.jar"
jar_path="./plantuml-1.2023.13.jar"
if [ -f $jar_path ]; then
   echo "File $jar_path exists."
else
   wget https://github.com/plantuml/plantuml/releases/download/v1.2023.13/plantuml-1.2023.13.jar
fi
java -Djava.awt.headless=true -jar $jar_path *.puml -tpng -o ../images/
