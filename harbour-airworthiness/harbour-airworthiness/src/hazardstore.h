#ifndef HAZARDSTORE_H
#define HAZARDSTORE_H

#include <QAbstractListModel>
#include <QJsonObject>
#include <QDate>

struct Hazard {
    int id = 0;
    QString aircraft;      // registration or type
    QString system;       // affected system / ATA chapter
    QString title;
    QString description;
    int severity = 1;      // 1..4
    int likelihood = 1;    // 1..5
    QString mitigation;
    QString owner;
    QString status;        // open / mitigated / closed
    QDate dueDate;
    qlonglong createdMs = 0;
    qlonglong updatedMs = 0;

    QJsonObject toJson() const;
    static Hazard fromJson(const QJsonObject &obj);
    int riskIndex() const { return severity * likelihood; }  // HRI 1-20 (AWB-150 / MIL-STD-882 style)
};

class HazardStore : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)
    Q_PROPERTY(QString filterStatus READ filterStatus WRITE setFilterStatus NOTIFY filterStatusChanged)

public:
    enum Roles {
        IdRole = Qt::UserRole + 1,
        AircraftRole, SystemRole, TitleRole, DescriptionRole,
        SeverityRole, SeverityNameRole, SeverityCodeRole,
        LikelihoodRole, LikelihoodNameRole, LikelihoodCodeRole,
        RiskIndexRole, RiskCategoryRole, RiskColorRole,
        MitigationRole, OwnerRole, StatusRole, DueDateRole,
        CreatedRole, UpdatedRole, HasDueDateRole
    };

    explicit HazardStore(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    Q_INVOKABLE void addHazard(const QVariantMap &data);
    Q_INVOKABLE void updateHazard(int id, const QVariantMap &data);
    Q_INVOKABLE void removeHazard(int id);
    Q_INVOKABLE QVariantMap getHazard(int id) const;
    Q_INVOKABLE int highestRiskIndex() const;
    Q_INVOKABLE int openCount() const;

    // Re-read the saved hazards from disk. Each page keeps its own store
    // instance, so pages must refresh when they become visible again.
    Q_INVOKABLE void reload();

    // Number of hazards that are not yet closed at a given matrix cell
    // (severity 1..4, likelihood 1..5). Used by the risk matrix page.
    Q_INVOKABLE int countAt(int severity, int likelihood) const;

    Q_INVOKABLE QString riskCategoryFor(int severity, int likelihood) const { return riskCategory(severity, likelihood); }
    Q_INVOKABLE QString riskColorFor(int severity, int likelihood) const { return riskColor(severity, likelihood); }
    Q_INVOKABLE QString severityNameFor(int severity) const { return severityName(severity); }
    Q_INVOKABLE QString likelihoodNameFor(int likelihood) const { return likelihoodName(likelihood); }
    Q_INVOKABLE QString severityCodeFor(int severity) const { return severityCode(severity); }
    Q_INVOKABLE QString likelihoodCodeFor(int likelihood) const { return likelihoodCode(likelihood); }
    Q_INVOKABLE QString riskCodeFor(int severity, int likelihood) const { return severityCode(severity) + likelihoodCode(likelihood); }

    QString filterStatus() const { return m_filterStatus; }
    void setFilterStatus(const QString &status);

    // AWB-150 4x5 matrix: severity 1..4 (I Catastrophic .. IV Negligible),
    // likelihood 1..5 (A Frequent .. E Improbable). Returns 0=High, 1=Serious,
    // 2=Medium, 3=Low.
    static int riskLevel(int severity, int likelihood);
    static QString riskCategory(int severity, int likelihood);
    static QString riskColor(int severity, int likelihood);
    static QString severityName(int severity);
    static QString likelihoodName(int likelihood);
    static QString severityCode(int severity);
    static QString likelihoodCode(int likelihood);

signals:
    void countChanged();
    void filterStatusChanged();

private:
    void load();
    void save();
    void repopulate();
    QString storagePath() const;

    QList<Hazard> m_all;
    QList<Hazard> m_visible;
    QString m_filterStatus;
    int m_nextId = 1;
};

#endif // HAZARDSTORE_H
