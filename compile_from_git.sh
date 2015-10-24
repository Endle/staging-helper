if [ ! -f config.sh ]; then
    cp config.sh.example config.sh
fi
source ./config.sh

export WORKING_DIR=$(pwd)

FETCH_WINE=0
FETCH_STAGE=0
NO_CONFIGURE=0
NO_MAKE=0
CLEAN_PATCHED=0
MAKE_OPTS="-j8" #FIXME: only support -Jn

for i in "$@"
do
    case $i in
    --fetch_wine)
        FETCH_WINE=1
        shift
        ;;
    --fetch_stage)
        FETCH_STAGE=1
        shift
        ;;
    -s|--simple)
        FETCH_STAGE=1
        FETCH_WINE=1
        shift
        ;;
    --no_make)
        NO_MAKE=1
        shift
        ;;
    --no_configure)
        NO_CONFIGURE=1
        shift
        ;;
    --clean)
        CLEAN_PATCHED=1
        shift
        ;;
    -j*)
        MAKE_OPTS=$1
        shift
        ;;
    *)
        ;;
esac
done

# FIXME: 考虑的情况太简单
if [ $FETCH_WINE \= 1 ]; then
    echo "Fetch Wine"
    cd $WINEGIT
    $WINE_FETCHER && git pull origin master
    cd $WORKING_DIR
fi
if [ $FETCH_STAGE \= 1 ]; then
    echo "Fetch Wine-Stage" cd $STAGING
    git pull origin master --force
    cd $WORKING_DIR
fi

echo "Copying wine-git code from"$WINEGIT
if [ -d "$WINE_PATCHED" ]; then
    cd $WINE_PATCHED
    git reset --hard origin/master
    if [ $CLEAN_PATCHED \= 1 ]; then
        git clean -dxf
    fi
    git pull origin master
else
    git clone $WINEGIT $WINE_PATCHED
    cd $WINE_PATCHED
fi

# Hack for old autoconf
export AUTOCONF_VERSION=`autoconf --version|head -n 1|cut -d " " -f 4`
if [ $AUTOCONF_VERSION \< 2.69 ]; then
    git am $WORKING_DIR/autoconf_hack.diff
    echo "Applying wine-staging patches from"$STAGING to $(pwd)
fi

function apply {
    $STAGING/patches/patchinstall.sh DESTDIR="$(pwd)" --all --force-autoconf --backend=git-am
}

function configure {
    if [ $NO_CONFIGURE \= 0 ]; then
        ./configure --with-xattr --prefix=$PREFIX CC="ccache gcc" CFLAGS="-g -O0 -m32"
    else
        false
    fi
}

function build {
    if [ $NO_MAKE \= 0 ]; then
        make $MAKE_OPTS
        #FIXME: not supported yet
        #make install
    fi
}

apply && configure && build
exit
