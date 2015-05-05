# Print primes up to MAX
# Check all odd numbers from START 
BEGIN {
	START = 3
	STEP = 2
	MAX = 999
	printf("%d\n",STEP)
	for(i=START; i < MAX;i+=STEP) {
		if (prime(i)) printf ("%d\n",i)
	}
}
function prime(n,i) {
	for (i=START; i < n; i+=STEP) {
		if (n % i == 0) return 0;
	}
	return 1;
}
