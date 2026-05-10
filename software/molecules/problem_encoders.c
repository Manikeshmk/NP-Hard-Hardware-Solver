#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

void encode_visit_constraints(int n, int **clauses, int *num_clauses) {
    int var_id = 1;
    *num_clauses = 0;

    for (int i = 0; i < n; i++) {
        for (int j = 0; j < n; j++) {
            if (i != j) {
                clauses[*num_clauses] = (int *)malloc(2 * sizeof(int));
                clauses[*num_clauses][0] = var_id + i * n + j;
                clauses[*num_clauses][1] = 0;
                (*num_clauses)++;
            }
        }
    }
}

void encode_cost_constraints(int n, int max_cost, int **clauses, int *num_clauses) {
    // Example: Add a dummy constraint for demonstration
    clauses[*num_clauses] = (int *)malloc(2 * sizeof(int));
    clauses[*num_clauses][0] = max_cost;
    clauses[*num_clauses][1] = 0;
    (*num_clauses)++;
}

int main() {
    int n = 4;
    int max_cost = 100;
    int *clauses[100];
    int num_clauses = 0;

    encode_visit_constraints(n, clauses, &num_clauses);
    encode_cost_constraints(n, max_cost, clauses, &num_clauses);

    printf("Encoded %d clauses\n", num_clauses);
    for (int i = 0; i < num_clauses; i++) {
        printf("Clause %d: %d\n", i + 1, clauses[i][0]);
        free(clauses[i]);
    }

    return 0;
}