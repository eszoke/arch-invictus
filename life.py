SPACE = ' '
DEAD_CELL = '+'
LIVE_CELL = 'O'

matrix = [ ['x', 'x', 'x', 'x', 'x', 'x', 'x', 'x'], ['x', '+', '+', '+', '+', '+', '+', 'x'], ['x', '+', '+', '+', '+', '+', '+', 'x'], ['x', '+', '+', '+', '+', '+', '+', 'x'], ['x', '+', '+', 'O', '+', 'O', '+', 'x'], ['x', '+', '+', '+', 'O', '+', '+', 'x'], ['x', '+', '+', '+', '+', '+', '+', 'x'], ['x', 'x', 'x', 'x', 'x', 'x', 'x', 'x'] ]

print()
print(*matrix[0], sep=' ')
print(*matrix[1], sep=' ')
print(*matrix[2], sep=' ')
print(*matrix[3], sep=' ')
print(*matrix[4], sep=' ')
print(*matrix[5], sep=' ')
print(*matrix[6], sep=' ')
print(*matrix[7], sep=' ')
print()

def printMatrix():
    for i in range(2, len(matrix)-2):
        for j in range(2, len(matrix[i])-2):
            print(matrix[i][j], end=SPACE)
        print()

def cellNeighbors(x, y):
    neighborCount = 0
    for i in range(x-1, x+1):
        for j in range(y-1, y+1):
            #if matrix[i][j] == LIVE_CELL:
            neighborCount += 1
    #if matrix[x][y] == LIVE_CELL:
        #neighborCount -= 1
    return neighborCount

print()
print(cellNeighbors(4, 4))
print()

printMatrix()
print()

gen2 = matrix

for i in range(len(matrix)):
    for j in range(len(matrix[i])):
        if matrix[i][j] == LIVE_CELL:
            if cellNeighbors(i, j) < 2 or cellNeighbors(i, j) > 3:
                gen2[i][j] = DEAD_CELL
            #if matrix[x][i-1] == '+':
                #print('H', end=SPACE)
        elif matrix[i][j] == DEAD_CELL:
            if cellNeighbors(i, j) == 3:
                gen2[i][j] = LIVE_CELL
            #print('z', end=SPACE)
    print()

