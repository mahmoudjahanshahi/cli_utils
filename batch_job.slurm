#!/bin/bash

# set variables
name="template"
start=0
total=128
step=4
partition="short"
threads=5

# variable calculations
finish=$((start + total))
n=$((step * threads))
if [[ $partition == "short" ]]; then 
    t=3
    ntask=12
else 
    t=24
    ntask=48
fi

for ((i=start; i<finish; i+=step)); do
    cat > $name.$i.slurm << EOT
#!/bin/bash
#SBATCH -A ACF-UTK0011 
#SBATCH -J $name.$i
#SBATCH --time=$t:00:00
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=$ntask
#SBATCH --partition=$partition
#SBATCH --qos=$partition
#SBATCH --output=$name.$i.o%j
#SBATCH --error=$name.$i.e%j

echo "Started running at \$(date)"
t0=\$(date +%s)

for i in {$i..$((i+step-1))}; do
    t1=\$(date +%s)

    ***CODE HERE***

    t2=\$(date +%s)
    elapsed=\$(date -d@\$(( t2 - t1 )) -u +%H" hours and "%M" minutes.")
    echo "finished $name.$i in \$elapsed"
done

t2=\$(date +%s)
elapsed=\$(date -d@\$(( t2 - t0 )) -u +%H" hours and "%M" minutes.")
echo "Completed $name.$i in \$elapsed"

EOT
    if (( i + n < finish )); then
        echo "sbatch $name.$((i+n)).slurm" >> $name.$i.slurm
    fi;
done;

stop=$((start + n < finish ? start + n : finish))

for ((i=start; i<stop; i+=step)); do
    sbatch $name.$i.slurm
done
