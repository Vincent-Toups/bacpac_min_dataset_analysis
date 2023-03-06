PORT_OFFSET=0
CONTAINER="ashar-emacs"
ENVIRONMENT=emacs

function usage {
echo "Usage: $0 [OPTIONS]"
echo "Options:"
echo " -p, --port-offset <OFFSET> Set the port offset (default: 0)"
echo " -c, --container <NAME> Set the container name (default: ashar-emacs)"
echo " -e, --environment <NAME> Set the environment (one of emacs, jupyter, rstudio)"
echo " -h, --help Show this help message and exit"
exit 1
}

while [[ $# -gt 0 ]]; do
case "$1" in
-p|--port-offset)
PORT_OFFSET=$2
shift 2
;;
-c|--container)
CONTAINER=$2
shift 2
;;
-e|--environment)
ENVIRONMENT=$2
-h|--help)
usage
;;
*)
echo "Unknown option: $1"
usage
;;
esac
done

echo "PORT_OFFSET: $PORT_OFFSET"
echo "CONTAINER: $CONTAINER"

export RSTUDIO_PORT=$(expr $PORT_OFFSET + 8788)
export D3_PORT=$(expr $PORT_OFFSET + 8889)

echo $PORT_OFFSET

case "$ENVIRONMENT" in
    emacs)
        COMMAND="emacs /home/rstudio/work"
        ;;
    jupyter)
        COMMAND="jupyter lab --port $RSTUDIO_PORT"
        echo Jupyter running on $RSTUDIO_PORT
        ;;
    rstudio)
        COMMAND=""
        echo RStudio on Port $RSTUDIO_PORT
        ;;
    *)
        echo "Unknown env (emacs, jupyter, or rstudio)"
        exit 1
        ;;
esac
done

#docker build . --build-arg linux_user_pwd="$(cat .password)" -t ashar
xhost +SI:localuser:$(whoami) 
docker run -p $D3_PORT:8888 \
       -p $RSTUDIO_PORT:8787 \
       -v $(pwd):/home/rstudio/work \
       -v $HOME/Downloads:/home/rstudio/Downloads\
       --user $UID \
       --workdir /home/rstudio/work\
       -e DISPLAY=$DISPLAY\
       -v /tmp/.X11-unix/:/tmp/.X11-unix/\
       -v $HOME/.Xauthority:/home/rstudio/.Xauthority\
       --cpus=6.5\
       -it $CONTAINER\
       emacs /home/rstudio/work

echo RSTUDIO on $RSTUDIO_PORT
echo EXTRA   on $D3_PORT

