dist: clean
	mkdir dist
	cd modem_ami && make && cd ..
	cp modem_ami/blink_config_bundle.zip dist/
	cd automation_bundle && make && cd ..
	cp automation_bundle/automation_bundle.zip dist/

clean:
	cd modem_ami && make clean && cd ..
	cd automation_bundle && make clean && cd ..
	rm -rf dist