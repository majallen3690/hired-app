"""Generates the sample resume PDF used for demos and testing. Run: python make_sample.py"""
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.units import mm
from reportlab.platypus import Paragraph, SimpleDocTemplate, Spacer

H = ParagraphStyle("h", fontName="Helvetica-Bold", fontSize=15, spaceAfter=2)
S = ParagraphStyle("s", fontName="Helvetica-Bold", fontSize=10.5, spaceBefore=9, spaceAfter=3)
B = ParagraphStyle("b", fontName="Helvetica", fontSize=9.5, leading=12.5, leftIndent=10, bulletIndent=0)
P = ParagraphStyle("p", fontName="Helvetica", fontSize=9.5, leading=12.5)

story = [
    Paragraph("Ishita Rao", H),
    Paragraph("ishita.rao@example.com | +91 98450 00000 | linkedin.com/in/ishita-rao-demo | github.com/ishita-rao-demo", P),
    Paragraph("EDUCATION", S),
    Paragraph("<b>PES University, Bengaluru</b> - B.Tech Computer Science and Engineering, 2023-2027, CGPA 8.4", P),
    Paragraph("SKILLS", S),
    Paragraph("Java, Python, C++, SQL, Flutter, Dart, Firebase, REST APIs, Git, Data Structures and Algorithms, OOP", P),
    Paragraph("PROJECTS", S),
    Paragraph("<b>Campus Attendance App</b> (Flutter, Firebase)", P),
    Paragraph("Built a mobile app for marking class attendance with QR codes", B, bulletText="-"),
    Paragraph("Worked on the backend using Firebase and made the login screen", B, bulletText="-"),
    Paragraph("Helped the team test the app with students", B, bulletText="-"),
    Paragraph("<b>Library Seat Finder</b> (Python, SQL)", P),
    Paragraph("Created a web tool that shows free seats in the college library", B, bulletText="-"),
    Paragraph("Reduced time students spend searching for a seat by 30%", B, bulletText="-"),
    Paragraph("EXPERIENCE", S),
    Paragraph("<b>Software Intern, Brightlabs Pvt Ltd</b> - May to July 2025", P),
    Paragraph("Fixed bugs in the company's internal dashboard written in Java", B, bulletText="-"),
    Paragraph("Wrote SQL queries for monthly reports", B, bulletText="-"),
    Paragraph("Participated in daily stand-ups and code reviews", B, bulletText="-"),
    Paragraph("CERTIFICATIONS", S),
    Paragraph("Google Associate Android Developer (in progress); NPTEL Data Structures and Algorithms", P),
]

doc = SimpleDocTemplate("sample_resume.pdf", pagesize=A4, leftMargin=18 * mm, rightMargin=18 * mm, topMargin=16 * mm, bottomMargin=14 * mm,
                        title="Ishita Rao - Resume")
doc.build(story)
print("wrote sample_resume.pdf")
