#!/bin/bash

confluent-hub install mongodb/kafka-connect-mongodb:1.2.0 --no-prompt


/config/start.sh connect-distributed