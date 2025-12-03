connect
targets -set -filter {name =~ "Hart #0*"}
catch {stop}
dow -clear boot.elf
con
exit
