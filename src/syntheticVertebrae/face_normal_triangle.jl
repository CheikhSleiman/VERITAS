function face_normal_triangle(f, V)
    p1, p2, p3 = V[Int(f[1])], V[Int(f[2])], V[Int(f[3])]
    a = p2 - p1
    b = p3 - p1
    n = cross(a, b)
    d = norm(n)
    d > 0 || return Point{3,Float64}(0,0,0)
    return Point{3,Float64}(n[1]/d, n[2]/d, n[3]/d)
end

