# SBT Version Manager

## Credits

Credit should go, where the credit is due. This script is a fork of the excellent Play! Framework Version Manager, created by [@kaiinkinen](https://github.com/kaiinkinen)
and Node Version Manager, created by Tim Casswell and Matthew Ranney. NVM is available here: https://github.com/creationix/nvm.git.
And PVM is available here: https://github.com/kaiinkinen/pvm.git. Latest changes will be pulled in, whenever it 
is feasible. Due to different code formatting and preferences this might turn out to be too hard in the long run. 

## Installation

SBT is a build tool for Scala, Java, and more, so in order for it to work you will need to 
have Java tooling in place.

To install create a folder somewhere in your filesystem with the "`svm.sh`" file inside it. I put mine in a folder called "`~/utils/svm`".
Having a separate directory for tools won't clutter your file listings, but is conveniently available when you need to access it.

Or if you have `git` installed, then just clone it:

    git clone git@github.com:grahamar/svm.git ~/utils/svm

To activate svm, you need to source it from your bash shell

    . ~/utils/svm/svm.sh

I always add this line to my ~/.bashrc or ~/.profile file to have it automatically sources upon login.
    
## Usage

To download, compile, and install the 0.13.0 release of SBT, do this:

    svm install 0.13.0

Find available versions in [link](http://dl.bintray.com/sbt/native-packages/sbt/):

	0.12.4, 0.13.0, 0.13.1, 0.13.11.2, 0.13.11, 0.13.12.1, 0.13.12, 0.13.13-RC1, 0.13.13-RC2, 0.13.13-RC3, 0.13.13.1, 0.13.13, 0.13.14-RC1, 0.13.14-RC2, 0.13.14, 0.13.15-RC2, 0.13.15, 0.13.2, 0.13.5-RC1, 0.13.5, 0.13.6, 0.13.7, 0.13.8, 0.13.9, 1.0.0-M1, 1.0.0-M4

And then in any new shell just use the installed version:

    svm use 0.13.0

Or you can just run it:

    svm run 0.13.0

If you want to see what versions are available:

    svm ls

To restore your PATH, you can deactivate it.

    svm deactivate

To set a default SBT version to be used in any new shell, use the alias 'default':

    svm alias default 0.13.0

## Bash completion

To activate, you need to source `bash_completion`:

  	[[ -r $SVM_DIR/bash_completion ]] && . $SVM_DIR/bash_completion

Put the above sourcing line just below the sourcing line for SVM in your profile (`.bashrc`, `.bash_profile`).

### Usage

svm

	$ svm [tab][tab]
	alias          copy-packages  help           list           run            uninstall      version        
	clear-cache    deactivate     install        ls             unalias        use

svm alias

	$ svm alias [tab][tab]
	default

	$ svm alias my_alias [tab][tab]
	0.12.3        0.12.4       0.13.0
	
svm use

	$ svm use [tab][tab]
	my_alias        default        0.12.3        0.12.4       0.13.0
	
svm uninstall

	$ svm uninstall [tab][tab]
	my_alias        default        0.12.3        0.12.4       0.13.0
	
